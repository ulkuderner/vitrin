import AppKit
import ApplicationServices

enum Permissions {

    /// Erişilebilirlik izni: olay yakalama (event tap) ve pencere odaklama için zorunlu.
    @discardableResult
    static func ensureAccessibility(prompt: Bool) -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [key: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static var hasAccessibility: Bool { AXIsProcessTrusted() }

    /// Ekran kaydı izni: pencere başlıkları ve önizleme görüntüleri için gerekli.
    static var hasScreenRecording: Bool { CGPreflightScreenCaptureAccess() }

    @discardableResult
    static func requestScreenRecording() -> Bool { CGRequestScreenCaptureAccess() }

    /// İzin verilene kadar arka planda yoklar; verildiğinde `onGranted` çağrılır.
    static func pollAccessibility(interval: TimeInterval = 1.0, onGranted: @escaping () -> Void) {
        guard !hasAccessibility else { onGranted(); return }
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            if hasAccessibility {
                timer.invalidate()
                onGranted()
            }
        }
    }

    static func openSettings(_ anchor: String) {
        // anchor örn: "Privacy_Accessibility" veya "Privacy_ScreenCapture"
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")!
        NSWorkspace.shared.open(url)
    }
}
