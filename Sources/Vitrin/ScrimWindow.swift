import AppKit
import QuartzCore

/// Anahtarlayıcı açıkken masaüstünü karartıp bulanıklaştıran tam ekran katman.
/// `behindWindow` harmanlama sayesinde gerçek masaüstü bulanıklaşır — ekran
/// görüntüsü almaya gerek yok, pencere sunucusu işi kendisi yapar.
@MainActor
final class ScrimWindow {

    private var window: NSWindow?
    private var dimView: NSView?
    private var blurView: NSVisualEffectView?

    func show(on screen: NSScreen, dim: Double, blurred: Bool, duration: TimeInterval) {
        let w = window ?? make()
        window = w

        w.setFrame(screen.frame, display: false)

        blurView?.isHidden = !blurred
        dimView?.layer?.backgroundColor = NSColor.black.withAlphaComponent(dim).cgColor

        w.alphaValue = 0
        w.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            w.animator().alphaValue = 1
        }
    }

    func hide(duration: TimeInterval) {
        guard let w = window, w.isVisible else { return }
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeIn)
            w.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated { w.orderOut(nil) }
        }
    }

    private func make() -> NSWindow {
        let w = NSWindow(contentRect: .zero, styleMask: [.borderless],
                         backing: .buffered, defer: false)
        w.isReleasedWhenClosed = false
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = false
        w.ignoresMouseEvents = true
        // Panelin hemen altında dursun.
        w.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue - 1)
        w.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let container = NSView()
        container.wantsLayer = true
        container.autoresizingMask = [.width, .height]

        let blur = NSVisualEffectView()
        blur.material = .fullScreenUI
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.autoresizingMask = [.width, .height]
        container.addSubview(blur)
        blurView = blur

        let dim = NSView()
        dim.wantsLayer = true
        dim.autoresizingMask = [.width, .height]
        container.addSubview(dim)
        dimView = dim

        w.contentView = container
        return w
    }
}
