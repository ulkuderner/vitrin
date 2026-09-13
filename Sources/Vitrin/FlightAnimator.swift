import AppKit
import QuartzCore

/// Seçim onaylandığında küçük resmi ızgaradaki hücreden gerçek pencerenin
/// konumuna uçurur. Kullanıcı hangi pencereye gittiğini gözüyle takip eder;
/// "nereye ışınlandım" hissi ortadan kalkar.
@MainActor
enum FlightAnimator {

    /// Uçuş süresince pencereye güçlü referans. Bu olmadan `fly` döndüğü anda
    /// NSWindow sahipsiz kalıyor ve animasyon temizliğinde aşırı release ile
    /// çöküyor (_NSWindowTransformAnimation dealloc → EXC_BAD_ACCESS).
    private static var inFlight: [NSWindow] = []

    /// - Parameters:
    ///   - image: uçacak küçük resim
    ///   - from: ekran koordinatlarında başlangıç çerçevesi (Cocoa, alt-sol orijin)
    ///   - to: hedef pencerenin CGWindowList çerçevesi (üst-sol orijin)
    static func fly(image: CGImage, from start: CGRect, to targetCG: CGRect,
                    completion: (() -> Void)? = nil) {

        let target = cocoaRect(fromCG: targetCG)
        guard start.width > 1, target.width > 1 else { completion?(); return }

        let window = NSWindow(contentRect: start,
                              styleMask: [.borderless],
                              backing: .buffered,
                              defer: false)
        window.isReleasedWhenClosed = false   // close() ile ikinci release olmasın
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let host = NSView(frame: NSRect(origin: .zero, size: start.size))
        host.wantsLayer = true
        host.layer?.contents = image
        host.layer?.contentsGravity = .resizeAspectFill
        host.layer?.masksToBounds = true
        host.layer?.cornerRadius = 8
        host.layer?.cornerCurve = .continuous
        window.contentView = host
        window.alphaValue = 0.95
        window.orderFrontRegardless()
        inFlight.append(window)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Motion.flight
            // Hızlı çık, yumuşak yerleş.
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 0.9, 0.2, 1)
            context.allowsImplicitAnimation = true
            window.animator().setFrame(target, display: true)
            window.animator().alphaValue = 0
        } completionHandler: {
            // Tamamlanma bloku Sendable; ana aktör izolasyonunu açıkça üstleniyoruz.
            MainActor.assumeIsolated {
                window.orderOut(nil)
                inFlight.removeAll { $0 === window }
            }
            completion?()
        }
    }

    /// Hedef pencerenin çevresinde bir kez atan ışıklı çerçeve. Uçuş inişini
    /// tamamlar: göz, pencerenin "geldiğini" görür.
    static func pulse(around targetCG: CGRect, color: NSColor, duration: TimeInterval = 0.42) {
        let target = cocoaRect(fromCG: targetCG)
        guard target.width > 1 else { return }

        let pad: CGFloat = 10
        let frame = target.insetBy(dx: -pad, dy: -pad)

        let window = NSWindow(contentRect: frame, styleMask: [.borderless],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        let host = NSView(frame: NSRect(origin: .zero, size: frame.size))
        host.wantsLayer = true
        guard let layer = host.layer else { return }
        layer.borderWidth = 3
        layer.borderColor = color.withAlphaComponent(0.95).cgColor
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        layer.shadowColor = color.cgColor
        layer.shadowOpacity = 0.9
        layer.shadowRadius = 18
        layer.shadowOffset = .zero
        window.contentView = host
        window.orderFrontRegardless()
        inFlight.append(window)

        // Dışarıdan içeri kapanan, sönerek biten tek atış.
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.06
        scale.toValue = 1.0
        scale.duration = duration
        scale.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 1.1, 0.3, 1)
        layer.add(scale, forKey: "pulseScale")

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = duration
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            window.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated {
                window.orderOut(nil)
                inFlight.removeAll { $0 === window }
            }
        }
    }

    /// CGWindowList üst-sol orijinli çerçeveyi Cocoa'nın alt-sol orijinine çevirir.
    static func cocoaRect(fromCG rect: CGRect) -> NSRect {
        guard let primary = NSScreen.screens.first else { return rect }
        let maxY = primary.frame.maxY
        return NSRect(x: rect.minX,
                      y: maxY - rect.maxY,
                      width: rect.width,
                      height: rect.height)
    }
}
