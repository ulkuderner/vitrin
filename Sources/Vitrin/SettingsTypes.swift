import SwiftUI
import CoreGraphics

// MARK: - Seçenek tipleri

enum TriggerKey: String, CaseIterable, Identifiable {
    case command, option
    var id: String { rawValue }
    var flag: CGEventFlags { self == .command ? .maskCommand : .maskAlternate }
    var symbol: String { self == .command ? "⌘" : "⌥" }
    var label: String { self == .command ? "⌘ Command" : "⌥ Option" }
}

/// Pencerelerin ekranda diziliş biçimi.
enum LayoutStyle: String, CaseIterable, Identifiable {
    case grid, filmstrip, coverflow, radial, book
    var id: String { rawValue }

    @MainActor
    var label: String { L10n.t("layout.\(rawValue)") }

    @MainActor
    var note: String { L10n.t("layout.\(rawValue).n") }

    /// Izgara dışındakiler tek sıra üzerinde çalışır.
    var isCarousel: Bool { self != .grid }
}

/// Hareket dilinin karakteri.
enum MotionStyle: String, CaseIterable, Identifiable {
    case none, snappy, spring, smooth, dramatic
    var id: String { rawValue }

    @MainActor
    var label: String { L10n.t("motion.\(rawValue)") }

    var select: Animation {
        switch self {
        case .none:     return .linear(duration: 0.001)
        case .snappy:   return .spring(response: 0.17, dampingFraction: 0.86)
        case .spring:   return .spring(response: 0.26, dampingFraction: 0.70)
        case .smooth:   return .easeInOut(duration: 0.32)
        case .dramatic: return .spring(response: 0.46, dampingFraction: 0.55)
        }
    }

    var appear: Animation {
        switch self {
        case .none:     return .linear(duration: 0.001)
        case .snappy:   return .spring(response: 0.24, dampingFraction: 0.88)
        case .spring:   return .spring(response: 0.40, dampingFraction: 0.80)
        case .smooth:   return .easeOut(duration: 0.36)
        case .dramatic: return .spring(response: 0.55, dampingFraction: 0.58)
        }
    }

    var thumb: Animation {
        self == .none ? .linear(duration: 0.001) : .easeOut(duration: 0.26)
    }

    var stagger: Double {
        switch self {
        case .none:     return 0
        case .snappy:   return 0.016
        case .spring:   return 0.028
        case .smooth:   return 0.034
        case .dramatic: return 0.060
        }
    }

    var panelIn: TimeInterval {
        switch self {
        case .none: return 0
        case .snappy: return 0.10
        case .spring: return 0.15
        case .smooth: return 0.22
        case .dramatic: return 0.28
        }
    }

    var panelOut: TimeInterval { self == .none ? 0 : panelIn * 0.7 }

    var flight: TimeInterval {
        switch self {
        case .none: return 0
        case .snappy: return 0.20
        case .spring: return 0.28
        case .smooth: return 0.34
        case .dramatic: return 0.48
        }
    }
}

/// Kartların sahneye giriş biçimi.
enum EntranceStyle: String, CaseIterable, Identifiable {
    case rise, fold, flip
    var id: String { rawValue }

    @MainActor
    var label: String { L10n.t("entrance.\(rawValue)") }

    @MainActor
    var note: String { L10n.t("entrance.\(rawValue).n") }
}

enum PanelMaterial: String, CaseIterable, Identifiable {
    case hud, dark, ultraThin, sidebar
    var id: String { rawValue }

    @MainActor
    var label: String { L10n.t("material.\(rawValue)") }

    var material: NSVisualEffectView.Material {
        switch self {
        case .hud:       return .hudWindow
        case .dark:      return .underPageBackground
        case .ultraThin: return .popover
        case .sidebar:   return .sidebar
        }
    }
}
