import ServiceManagement
import os

/// Oturum açılışında otomatik başlatma. SMAppService ile login item'ı
/// uygulamanın kendisi kaydeder; kullanıcının Sistem Ayarları'na gitmesi
/// gerekmez. Kayıt bundle kimliğine bağlıdır.
@MainActor
enum LoginItem {

    private static let log = Logger(subsystem: "com.profelis.vitrin", category: "login")

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Kullanıcı Sistem Ayarları'ndan elle kapatmışsa bunu bildirir.
    static var requiresApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
            log.notice("login item: \(enabled)")
            return true
        } catch {
            log.error("login item hatasi: \(error.localizedDescription)")
            return false
        }
    }

    /// Uygulama oturum açılışında launchd tarafından mı başlatıldı?
    /// Böyle başladıysa hiçbir pencere açmayıp sessiz kalırız.
    static func launchedAtLogin() -> Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent else { return false }
        guard event.eventID == kAEOpenApplication else { return false }
        return event.paramDescriptor(forKeyword: keyAEPropData)?
            .enumCodeValue == keyAELaunchedAsLogInItem
    }
}
