import AppKit
import CoreGraphics
import os

private let tapLog = Logger(subsystem: "com.profelis.vitrin", category: "tap")

/// ⌥ basılıyken Tab / ` tuşlarını yakalar ve sistemin varsayılan
/// uygulama değiştiricisine ulaşmadan yutar.
final class HotkeyTap {

    enum Action {
        case cycle(backwards: Bool, sameApp: Bool)
        case move(dx: Int, dy: Int)
        case commit
        case cancel
        case closeSelected
        case quitSelectedApp
        case minimizeSelected
        case openSettings
    }

    /// Ana iş parçacığında çağrılır.
    var onAction: ((Action) -> Void)?
    /// Overlay şu anda açık mı?
    var isActive: () -> Bool = { false }

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?

    func start() -> Bool {
        let mask = (1 << CGEventType.keyDown.rawValue)
                 | (1 << CGEventType.keyUp.rawValue)
                 | (1 << CGEventType.flagsChanged.rawValue)

        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let me = Unmanaged<HotkeyTap>.fromOpaque(refcon).takeUnretainedValue()
                return me.handle(type: type, event: event)
            },
            userInfo: refcon
        ) else { return false }

        self.tap = tap
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    // MARK: - Olay işleme

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Sistem tap'i zaman aşımıyla kapatırsa geri aç.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }

        let flags = event.flags
        let triggerDown = flags.contains(MainActor.assumeIsolated { Settings.shared.trigger.flag })
        let shiftDown = flags.contains(.maskShift)
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let active = isActive()

        switch type {
        case .flagsChanged:
            // ⌥ bırakıldı -> seçimi uygula.
            if active && !triggerDown {
                emit(.commit)
            }
            return Unmanaged.passUnretained(event)

        case .keyDown:
            // Yalnizca Tab / ` icin log; diger tuslar hic kaydedilmez.
            if keyCode == Config.Key.tab || keyCode == Config.Key.grave {
                tapLog.notice("""
                    tus=\(keyCode) tetik=\(triggerDown) \
                    opt=\(flags.contains(.maskAlternate)) cmd=\(flags.contains(.maskCommand)) \
                    shift=\(shiftDown) ham=\(flags.rawValue)
                    """)
            }
            if triggerDown && (keyCode == Config.Key.tab || keyCode == Config.Key.grave) {
                emit(.cycle(backwards: shiftDown, sameApp: keyCode == Config.Key.grave))
                return nil // yut: macOS'un kendi ⌘⇥ benzeri davranışına gitmesin
            }
            guard active else { return Unmanaged.passUnretained(event) }

            switch keyCode {
            case Config.Key.escape:      emit(.cancel);              return nil
            case Config.Key.leftArrow:   emit(.move(dx: -1, dy: 0));  return nil
            case Config.Key.rightArrow:  emit(.move(dx: 1, dy: 0));   return nil
            case Config.Key.upArrow:     emit(.move(dx: 0, dy: -1));  return nil
            case Config.Key.downArrow:   emit(.move(dx: 0, dy: 1));   return nil
            case Config.Key.q:           emit(.quitSelectedApp);     return nil
            case Config.Key.w:           emit(.closeSelected);       return nil
            case Config.Key.m:           emit(.minimizeSelected);    return nil
            case Config.Key.comma:       emit(.openSettings);        return nil
            default:                     return nil // oturum sırasında diğer tuşları da yut
            }

        case .keyUp:
            if active && (keyCode == Config.Key.tab || keyCode == Config.Key.grave) {
                return nil
            }
            return Unmanaged.passUnretained(event)

        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func emit(_ action: Action) {
        // Tap geri çağrısı zaten ana run loop'ta çalışıyor, ama UI işini
        // olay işlemeden sonraya bırakmak tap'in zaman aşımına uğramasını önler.
        DispatchQueue.main.async { [weak self] in
            self?.onAction?(action)
        }
    }
}
