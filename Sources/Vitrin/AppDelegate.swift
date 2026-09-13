import AppKit
import Combine
import os

private let log = Logger(subsystem: "com.profelis.vitrin", category: "app")

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private let store = WindowStore()
    private let controller = SwitcherController()
    private let hotkeys = HotkeyTap()
    private var statusItem: NSStatusItem?
    private var statusLine: NSMenuItem?
    private let settingsWindow = SettingsWindowController()
    private let aboutWindow = AboutWindowController()
    private var tapRunning = false
    private var previewToken = 0
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        observeStatusIconSetting()
        trackFrontmostApp()

        controller.model.iconProvider = { [store] pid in store.icon(for: pid) }
        controller.model.onPick = { [weak self] index in
            self?.controller.model.selected = index
            self?.commit()
        }
        Settings.shared.onPreview = { [weak self] in
            self?.runPreview()
        }
        // Hakkında penceresindeki "Ayarlar…" düğmesi.
        NotificationCenter.default.addObserver(
            forName: .vitrinOpenSettings, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.settingsWindow.show() }
        }

        // HotkeyTap geri çağrıları ana run loop'ta çalışır, ama tipleri
        // izolasyonsuzdur. @MainActor kapanışı doğrudan atamak aktör bilgisini
        // kaybettirir; izolasyonu açıkça üstleniyoruz.
        hotkeys.isActive = { [weak self] in
            MainActor.assumeIsolated { self?.controller.isVisible ?? false }
        }
        hotkeys.onAction = { [weak self] action in
            MainActor.assumeIsolated { self?.handle(action) }
        }

        Permissions.requestScreenRecording()
        log.notice("baslangic ax=\(Permissions.hasAccessibility) sr=\(Permissions.hasScreenRecording)")

        if Permissions.ensureAccessibility(prompt: true) {
            startTap()
        } else {
            warnMissingAccessibility()
            Permissions.pollAccessibility { [weak self] in
                Task { @MainActor in
                    log.notice("erisilebilirlik izni geldi, tap kuruluyor")
                    self?.startTap()
                }
            }
        }

        // Oturum açılışında sessiz başla. Elle açıldıysa ve menü çubuğu ikonu
        // kapalıysa ayarları göster — aksi halde kullanıcının hiçbir girişi kalmaz.
        if LoginItem.launchedAtLogin() {
            log.notice("oturum acilisinda sessiz baslangic")
        } else if !Settings.shared.showStatusIcon {
            settingsWindow.show()
        }
    }

    /// Menü çubuğu ikonu kapalıyken uygulamayı Finder'dan (ya da `open -a Vitrin`
    /// ile) yeniden açmak ayarları gösterir — geri dönüş yollarından biri.
    func applicationShouldHandleReopen(_ sender: NSApplication,
                                       hasVisibleWindows: Bool) -> Bool {
        settingsWindow.show()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Bu satir logda varsa kapanis normaldir (kullanici ya da sistem istegi).
        // Yoksa anormal bir sonlanma var demektir.
        log.notice("uygulama kapaniyor")
        hotkeys.stop()
    }

    // MARK: - Kurulum

    private func startTap() {
        tapRunning = hotkeys.start()
        log.notice("event tap kuruldu: \(self.tapRunning)")
        guard !tapRunning else { return }

        let alert = NSAlert()
        alert.messageText = L10n.t("alert.tap.title")
        alert.informativeText = L10n.t("alert.tap.body")
        alert.addButton(withTitle: L10n.t("alert.openSettings"))
        alert.addButton(withTitle: L10n.t("alert.close"))
        if alert.runModal() == .alertFirstButtonReturn {
            Permissions.openSettings("Privacy_Accessibility")
        }
    }

    private func warnMissingAccessibility() {
        log.error("erisilebilirlik izni yok; tap kurulamiyor")
        let alert = NSAlert()
        alert.messageText = L10n.t("alert.ax.title")
        alert.informativeText = L10n.t("alert.ax.body")
        alert.addButton(withTitle: L10n.t("alert.openSettings"))
        alert.addButton(withTitle: L10n.t("alert.later"))
        if alert.runModal() == .alertFirstButtonReturn {
            Permissions.openSettings("Privacy_Accessibility")
        }
    }

    private func setupStatusItem() {
        guard Settings.shared.showStatusIcon else { return }
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        // Şablon görüntü: menü çubuğu rengine ve vurgulanma durumuna göre
        // sistem tarafından boyanır — sabit renkli ikon Apple standardına aykırı.
        let icon = NSImage(systemSymbolName: "square.grid.2x2",
                           accessibilityDescription: "Vitrin")
        icon?.isTemplate = true
        item.button?.image = icon
        let menu = NSMenu()
        menu.delegate = self

        // Teşhis satırı; menü her açıldığında tazelenir.
        let status = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        statusLine = status

        menu.addItem(.separator())

        // Kısayol çalışmıyorsa boru hattının geri kalanını sınamak için.
        let prefs = NSMenuItem(title: L10n.t("menu.settings"), action: #selector(openSettings),
                               keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)

        let about = NSMenuItem(title: L10n.t("menu.about"), action: #selector(openAbout),
                               keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        let test = NSMenuItem(title: L10n.t("menu.showNow"),
                              action: #selector(showNow), keyEquivalent: "")
        test.target = self
        menu.addItem(test)

        menu.addItem(.separator())

        let ax = NSMenuItem(title: L10n.t("menu.accessibility"),
                            action: #selector(openAccessibility), keyEquivalent: "")
        ax.target = self
        menu.addItem(ax)

        let sc = NSMenuItem(title: L10n.t("menu.screenRecording"),
                            action: #selector(openScreenRecording), keyEquivalent: "")
        sc.target = self
        menu.addItem(sc)

        let retry = NSMenuItem(title: L10n.t("menu.retryTap"),
                               action: #selector(retryTap), keyEquivalent: "")
        retry.target = self
        menu.addItem(retry)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: L10n.t("menu.quit"),
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        item.menu = menu
        statusItem = item
    }

    /// Ayar değiştikçe ikonu ekler ya da kaldırır.
    private func observeStatusIconSetting() {
        Settings.shared.$showStatusIcon
            .removeDuplicates()
            .sink { [weak self] visible in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if visible {
                        self.setupStatusItem()
                    } else if self.statusItem != nil {
                        // Kaldırmayı bir sonraki çevrime bırakıyoruz: yayıncı henüz
                        // ateşlenirken durum öğesini sökmek çökmeye yol açabiliyor.
                        DispatchQueue.main.async {
                            guard let item = self.statusItem else { return }
                            NSStatusBar.system.removeStatusItem(item)
                            self.statusItem = nil
                            self.statusLine = nil
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    func menuWillOpen(_ menu: NSMenu) {
        let ax = Permissions.hasAccessibility ? "✓" : "✗"
        let sr = Permissions.hasScreenRecording ? "✓" : "✗"
        let tap = tapRunning ? "✓" : "✗"
        statusLine?.title = "\(L10n.t("status.ax")) \(ax)   \(L10n.t("status.sr")) \(sr)   "
            + "\(L10n.t("status.tap")) \(tap)"
    }

    @objc private func showNow() {
        // Fare ile seçim tap'ten bağımsız çalışır; panel açılıyorsa sorun
        // yalnızca kısayolda demektir.
        open(sameAppOnly: false, backwards: false)
    }

    @objc private func retryTap() {
        hotkeys.stop()
        tapRunning = false
        startTap()
    }

    @objc private func openSettings() { settingsWindow.show() }
    @objc private func openAbout() { aboutWindow.show() }

    @objc private func toggleMinimized(_ sender: NSMenuItem) {
        Settings.shared.includeMinimized.toggle()
        sender.state = Settings.shared.includeMinimized ? .on : .off
    }

    @objc private func openAccessibility() { Permissions.openSettings("Privacy_Accessibility") }
    @objc private func openScreenRecording() { Permissions.openSettings("Privacy_ScreenCapture") }

    /// Uygulama değiştikçe MRU'yu güncel tut, böylece ⌥⇥ ilk basışta
    /// bir öncekine geçer.
    private func trackFrontmostApp() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { [weak self] note in
            guard let self,
                  let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            else { return }
            MainActor.assumeIsolated {
                if let front = self.store.onScreenWindows()
                    .first(where: { $0.pid == app.processIdentifier }) {
                    self.store.touch(front.id)
                }
            }
        }
    }

    // MARK: - Oturum akışı

    private func handle(_ action: HotkeyTap.Action) {
        switch action {
        case .cycle(let backwards, let sameApp):
            previewToken += 1        // süren önizlemeyi iptal et
            if controller.isVisible {
                controller.move(by: backwards ? -1 : 1)
            } else {
                open(sameAppOnly: sameApp, backwards: backwards)
            }

        case .move(let dx, let dy):
            controller.move(dx: dx, dy: dy)

        case .commit:
            commit()

        case .cancel:
            controller.hide()

        case .closeSelected:
            if let w = controller.model.current { Activator.close(w); controller.removeCurrent() }

        case .minimizeSelected:
            if let w = controller.model.current { Activator.minimize(w); controller.removeCurrent() }

        case .quitSelectedApp:
            if let w = controller.model.current { Activator.quitApp(w); controller.removeCurrent() }

        case .openSettings:
            controller.hide()
            settingsWindow.show()
        }
    }

    /// Önizleme: paneli açar, seçimi birkaç kez ilerletip geçiş animasyonunu
    /// gösterir ve kendiliğinden kapanır. Pencere değiştirmez, MRU'ya dokunmaz.
    private func runPreview() {
        open(sameAppOnly: false, backwards: false)
        guard controller.isVisible else { return }

        previewToken += 1
        let token = previewToken
        let beat = max(Motion.panelIn, 0.12) + 0.42

        func step(_ delay: Double, _ work: @escaping () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                // Kullanıcı bu arada gerçek bir oturum açtıysa önizlemeyi bırak.
                guard let self, self.previewToken == token else { return }
                work()
            }
        }

        step(beat) { [weak self] in self?.controller.move(by: 1) }
        step(beat * 2) { [weak self] in self?.controller.move(by: 1) }
        step(beat * 3.2) { [weak self] in
            guard let self, self.previewToken == token else { return }
            let target = Settings.shared.collapseToSelection
                ? self.controller.selectedCellScreenFrame() : nil
            self.controller.hide(collapsingTo: target)
        }
    }

    private func open(sameAppOnly: Bool, backwards: Bool) {
        let windows = store.snapshot(sameAppOnly: sameAppOnly)
        log.notice("oturum: \(windows.count) pencere sadeceAyniUygulama=\(sameAppOnly)")
        guard !windows.isEmpty else { return }
        // MRU'da 0 mevcut pencere; ilk ⌥⇥ bir öncekini seçmeli.
        let start = windows.count > 1 ? (backwards ? windows.count - 1 : 1) : 0
        controller.show(windows: windows, sameAppOnly: sameAppOnly, startIndex: start)
    }

    private func commit() {
        guard controller.isVisible else { return }
        guard let target = controller.model.current else { controller.hide(); return }

        let s = Settings.shared
        let image = controller.thumbnail(for: target.id)
        let start = controller.selectedCellScreenFrame()
        let landable = !target.isMinimized && target.bounds.width > 1

        // Panel seçili kartın üzerine büzülerek kapanır, uçuş oradan devam eder.
        controller.hide(collapsingTo: s.collapseToSelection ? start : nil)
        store.touch(target.id)
        Activator.focus(target)

        guard landable else { return }

        if s.flight, let image, let start {
            FlightAnimator.fly(image: image, from: start, to: target.bounds)
        }

        if s.arrivalPulse {
            // Uçuş inerken değil, indikten hemen sonra atsın.
            let delay = s.flight ? Motion.flight * 0.8 : 0
            let color = arrivalColor(for: target, image: image)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                FlightAnimator.pulse(around: target.bounds, color: color)
            }
        }
    }

    /// Parıltı rengi: küçük resim varsa pencerenin kendi baskın rengi.
    private func arrivalColor(for window: WindowInfo, image: CGImage?) -> NSColor {
        guard Settings.shared.tintGlow, let image else { return .controlAccentColor }
        return NSColor(DominantColor.of(image, id: window.id))
    }
}
