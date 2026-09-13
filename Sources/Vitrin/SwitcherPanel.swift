import AppKit
import SwiftUI

/// Odağı çalmayan, tüm masaüstlerinde görünen overlay penceresi.
final class SwitcherPanel: NSPanel {

    init(content: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 400),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .popUpMenu
        isOpaque = false
        backgroundColor = .clear
        // Gölge varsayılan olarak kapalı: saydam bir pencerede AppKit gölgeyi
        // içeriğin alfa siluetine göre üretir ve kartların çevresinde ince bir
        // hâle bırakır. Gerektiğinde show() içinde açılıyor.
        hasShadow = false
        hidesOnDeactivate = false
        isMovable = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle, .stationary]
        contentView = content
        contentView?.wantsLayer = true
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Fare imlecinin bulunduğu ekranın ortasına yerleştir.
    func centerOnActiveScreen() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let visible = screen?.visibleFrame else { return }

        let fitting = contentView?.fittingSize ?? frame.size
        let width = min(fitting.width, visible.width - 80)
        let height = min(fitting.height, visible.height - 80)
        setContentSize(NSSize(width: width, height: height))
        setFrameOrigin(NSPoint(x: visible.midX - width / 2, y: visible.midY - height / 2))
    }

    /// Alpha + hafif ölçek ile açılış. Panelin kendisi anında yerinde,
    /// hücrelerin sıralı belirişi SwiftUI tarafında.
    func fadeIn() {
        alphaValue = 0
        contentView?.layer?.transform = CATransform3DMakeScale(0.97, 0.97, 1)
        orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Motion.panelIn
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            animator().alphaValue = 1
            contentView?.layer?.transform = CATransform3DIdentity
        }
    }

    func fadeOut(toward target: CGRect? = nil, completion: (() -> Void)? = nil) {
        let start = frame
        NSAnimationContext.runAnimationGroup { context in
            context.duration = Motion.panelOut
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            context.allowsImplicitAnimation = true
            animator().alphaValue = 0
            if let target {
                // Panel seçili kartın üzerine büzülür; uçuş tam oradan devam eder.
                animator().setFrame(target, display: false)
            } else {
                contentView?.layer?.transform = CATransform3DMakeScale(0.98, 0.98, 1)
            }
        } completionHandler: { [weak self] in
            guard let self else { return }
            self.orderOut(nil)
            self.contentView?.layer?.transform = CATransform3DIdentity
            if target != nil { self.setFrame(start, display: false) }
            completion?()
        }
    }
}

/// Panelin ömrünü ve modelini yöneten katman.
@MainActor
final class SwitcherController {

    let model = SwitcherModel()
    private var panel: SwitcherPanel?
    private var captureTask: Task<Void, Never>?
    private let scrim = ScrimWindow()
    private var mouseMonitor: Any?

    var isVisible: Bool { (panel?.isVisible ?? false) && (panel?.alphaValue ?? 0) > 0.01 }

    func show(windows: [WindowInfo], sameAppOnly: Bool, startIndex: Int) {
        model.windows = windows
        model.sameAppOnly = sameAppOnly
        model.thumbs = [:]
        model.cellFrames = [:]
        model.selected = windows.isEmpty ? 0 : min(max(0, startIndex), windows.count - 1)
        model.sessionID = UUID()

        let panel = self.panel ?? makePanel()
        self.panel = panel
        // Pencere gölgesi hiçbir koşulda kullanılmıyor: saydam içerikte AppKit
        // gölgeyi alfa siluetine göre üretiyor ve her görünen öğenin çevresine
        // ince bir kontur bırakıyor. Gölge gerekiyorsa SwiftUI tarafında,
        // yalnızca panel zemininin altına çiziliyor.
        panel.hasShadow = false
        panel.layoutIfNeeded()
        panel.centerOnActiveScreen()

        // Masaüstü kararması panelden önce girsin ki panel onun üzerine otursun.
        let s = Settings.shared
        if s.scrim {
            let screen = NSScreen.screens.first {
                NSMouseInRect(NSEvent.mouseLocation, $0.frame, false)
            } ?? NSScreen.main
            if let screen {
                scrim.show(on: screen,
                           dim: s.scrimDim,
                           blurred: s.scrimBlur && !SystemAccess.shared.reduceTransparency,
                           duration: max(Motion.panelIn, 0.12))
            }
        }

        panel.fadeIn()
        // Gölge durumu değiştiğinde AppKit önbelleği geçersiz kılınmalı;
        // aksi halde eski silueti çizmeye devam eder.
        panel.invalidateShadow()
        startPointerTracking()
        startCapture(for: windows.map(\.id))
    }

    func hide(animated: Bool = true, collapsingTo target: CGRect? = nil) {
        captureTask?.cancel()
        captureTask = nil
        stopPointerTracking()
        scrim.hide(duration: max(Motion.panelOut, 0.1))
        if animated {
            panel?.fadeOut(toward: target)
        } else {
            panel?.orderOut(nil)
            panel?.alphaValue = 1
        }
    }

    // MARK: - Paralaks

    private func startPointerTracking() {
        guard Settings.shared.parallax,
              !SystemAccess.shared.reduceMotion,
              mouseMonitor == nil else { return }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            MainActor.assumeIsolated { self?.updatePointer() }
        }
        updatePointer()
    }

    private func stopPointerTracking() {
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        mouseMonitor = nil
        model.pointer = .zero
    }

    private func updatePointer() {
        guard let panel, panel.isVisible else { return }
        let f = panel.frame
        guard f.width > 1, f.height > 1 else { return }
        let m = NSEvent.mouseLocation
        // Panel merkezine göre -1…1; dışarıda kalırsa kırpılır.
        let x = max(-1, min(1, (m.x - f.midX) / (f.width / 2)))
        let y = max(-1, min(1, (m.y - f.midY) / (f.height / 2)))
        model.pointer = CGPoint(x: x, y: y)
    }

    /// Seçili hücrenin ekran koordinatlarındaki çerçevesi (uçuş başlangıcı).
    func selectedCellScreenFrame() -> CGRect? {
        guard let panel, let id = model.current?.id,
              let local = model.cellFrames[id] else { return nil }
        // SwiftUI .global koordinatları: sol-üst orijinli, panelin içerik alanına göre.
        let panelFrame = panel.frame
        return CGRect(x: panelFrame.minX + local.minX,
                      y: panelFrame.maxY - local.maxY,
                      width: local.width,
                      height: local.height)
    }

    func thumbnail(for id: CGWindowID) -> CGImage? { model.thumbs[id] }

    func move(by delta: Int) {
        guard !model.windows.isEmpty else { return }
        // Basış hızını kaydet: hızlı tekrarda animasyon kısalır.
        Motion.noteSelectionChange()
        let count = model.windows.count
        model.selected = ((model.selected + delta) % count + count) % count
    }

    func move(dx: Int, dy: Int) {
        guard !model.windows.isEmpty else { return }
        if dx != 0 { move(by: dx) }
        // Izgara dışı dizilişlerde tek sıra var; dikey oklar da ilerletir.
        if dy != 0 {
            let step = Settings.shared.layout.isCarousel
                ? dy
                : dy * model.columns(Int(Settings.shared.maxColumns))
            move(by: step)
        }
    }

    func removeCurrent() {
        guard model.windows.indices.contains(model.selected) else { return }
        // withAnimation sonuç döndürür; yok saydığımızı açıkça belirtiyoruz.
        _ = withAnimation(Motion.select) {
            model.windows.remove(at: model.selected)
        }
        if model.windows.isEmpty { hide() }
        else { model.selected = min(model.selected, model.windows.count - 1) }
    }

    private func makePanel() -> SwitcherPanel {
        let hosting = NSHostingView(rootView: SwitcherView(model: model))
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.autoresizingMask = [.width, .height]
        // NSHostingView kendi katmanına opak bir zemin koyabiliyor; panel saydam
        // olduğunda geride kalan o zemin "taşıyıcı alan" olarak görünüyordu.
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.layer?.isOpaque = false
        return SwitcherPanel(content: hosting)
    }

    private func startCapture(for ids: [CGWindowID]) {
        captureTask?.cancel()
        let model = self.model
        let width = Settings.shared.capturePixelWidth
        captureTask = Task {
            await Capture.thumbnails(for: ids, pixelWidth: width) { id, image in
                Task { @MainActor in
                    withAnimation(Motion.thumb) { model.thumbs[id] = image }
                }
            }
        }
    }
}
