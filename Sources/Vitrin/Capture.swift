import CoreGraphics
import ScreenCaptureKit

/// Pencere önizlemelerini ScreenCaptureKit ile yakalar (macOS 14+).
enum Capture {

    /// Verilen pencere kimlikleri için küçük resim üretir.
    /// Her görüntü hazır oldukça `onImage` çağrılır, böylece overlay
    /// beklemeden açılıp kareleri tek tek doldurabilir.
    static func thumbnails(
        for ids: [CGWindowID],
        pixelWidth: Int = 640,
        onImage: @escaping @Sendable (CGWindowID, CGImage) -> Void
    ) async {
        guard Permissions.hasScreenRecording else { return }

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.excludingDesktopWindows(
                true, onScreenWindowsOnly: true)
        } catch {
            return
        }

        let wanted = Set(ids)
        let targets = content.windows.filter { wanted.contains($0.windowID) }

        await withTaskGroup(of: Void.self) { group in
            for window in targets {
                group.addTask {
                    guard let image = await capture(window, pixelWidth: pixelWidth) else { return }
                    onImage(window.windowID, image)
                }
            }
        }
    }

    private static func capture(_ window: SCWindow, pixelWidth: Int) async -> CGImage? {
        let filter = SCContentFilter(desktopIndependentWindow: window)

        let config = SCStreamConfiguration()
        let aspect = window.frame.height > 0 ? window.frame.width / window.frame.height : 16.0 / 9.0
        config.width = pixelWidth
        config.height = max(1, Int((Double(pixelWidth) / max(aspect, 0.1)).rounded()))
        config.showsCursor = false
        config.captureResolution = .best

        return try? await SCScreenshotManager.captureImage(
            contentFilter: filter, configuration: config)
    }
}
