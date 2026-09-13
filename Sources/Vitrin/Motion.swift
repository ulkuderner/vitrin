import SwiftUI

/// Hareket dili. Üç girdiden beslenir: kullanıcının seçtiği karakter, sistemin
/// "Hareketi Azalt" tercihi ve kullanıcının o anki basış hızı.
///
/// Sonuncusu Apple'ın az konuşulan ama en çok hissedilen detayı: kısayolu hızlı
/// hızlı tekrarlarken animasyon kısalmalı, yoksa arayüz kullanıcının gerisinde
/// kalır. Yay tabanlı animasyonlar kesilebilir olduğu için ortada kalan hareket
/// yeni hedefe hızını koruyarak akar.
@MainActor
enum Motion {

    private static var style: MotionStyle {
        SystemAccess.shared.reduceMotion ? .none : Settings.shared.motion
    }

    /// Ardışık seçim değişimleri arasındaki süre; hızlı basışta animasyon kısalır.
    private static var lastSelectionChange = Date.distantPast
    private static var rapid = false

    static func noteSelectionChange() {
        let now = Date()
        rapid = now.timeIntervalSince(lastSelectionChange) < 0.22
        lastSelectionChange = now
    }

    static var select: Animation {
        guard style != .none else { return .linear(duration: 0.001) }
        // Hızlı basışta Apple'ın .snappy karakterine düşüyoruz: aynı yay ailesi,
        // daha kısa tepki süresi, overshoot yok.
        return rapid ? .snappy(duration: 0.18, extraBounce: 0) : style.select
    }

    static var appear: Animation { style.appear }
    static var thumb: Animation { style.thumb }
    static var title: Animation {
        style == .none ? .linear(duration: 0.001) : .easeOut(duration: 0.16)
    }

    static var panelIn: TimeInterval { style.panelIn }
    static var panelOut: TimeInterval { style.panelOut }

    static var flight: TimeInterval {
        guard Settings.shared.flight, !SystemAccess.shared.reduceMotion else { return 0 }
        return style.flight
    }

    static let maxStagger: Double = 0.24

    static func staggerDelay(_ index: Int) -> Double {
        guard Settings.shared.staggered, style != .none else { return 0 }
        // Hızlı basışta sıralama gecikmesi bırakılır; kullanıcı beklemek istemiyor.
        guard !rapid else { return 0 }
        return min(Double(index) * style.stagger, maxStagger)
    }

    /// Malzeme ve bulanıklık, "Saydamlığı Azalt" açıkken devre dışı.
    static var allowsTransparency: Bool { !SystemAccess.shared.reduceTransparency }
}
