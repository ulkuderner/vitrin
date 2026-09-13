// Vitrin — macOS window-level switcher
// Copyright (C) 2026 Çağlar Ülküderner
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your option)
// any later version. See <https://www.gnu.org/licenses/> for details.
//
// https://github.com/ulkuderner/vitrin

import Foundation
import SwiftUI

/// Desteklenen diller. `code`, Strings tablosundaki anahtarla aynı.
enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case en, tr, de, fr, es, it, pt, nl, pl, ru, ja, ko

    var id: String { rawValue }

    var code: String {
        switch self {
        case .system: return resolved.code
        default:      return rawValue
        }
    }

    /// Her dil kendi adıyla listelenir.
    var label: String {
        switch self {
        case .system: return "Sistem / System"
        case .en:     return "English"
        case .tr:     return "Türkçe"
        case .de:     return "Deutsch"
        case .fr:     return "Français"
        case .es:     return "Español"
        case .it:     return "Italiano"
        case .pt:     return "Português"
        case .nl:     return "Nederlands"
        case .pl:     return "Polski"
        case .ru:     return "Русский"
        case .ja:     return "日本語"
        case .ko:     return "한국어"
        }
    }

    /// Sistem seçiliyken kullanıcının tercih ettiği dilden türetilir.
    var resolved: AppLanguage {
        guard self == .system else { return self }
        guard let pref = Locale.preferredLanguages.first else { return .en }
        let base = String(pref.prefix(2)).lowercased()
        return AppLanguage.allCases.first { $0 != .system && $0.rawValue == base } ?? .en
    }
}

/// Bağımlılıksız yerelleştirme. SPM çalıştırılabilirinde .lproj paketlemek ek
/// kaynak yönetimi gerektirdiği için sözlük tabanlı; dil değişince arayüz
/// anında güncellenir.
///
/// Arama zinciri: seçilen dil → İngilizce → anahtarın kendisi. Yedek sayesinde
/// yeni bir dil eklerken tüm anahtarları aynı anda çevirmek gerekmez; eksikler
/// İngilizce görünür, arayüz hiçbir yerde boş kalmaz.
@MainActor
enum L10n {
    static func t(_ key: String) -> String {
        let code = Settings.shared.language.resolved.code
        if let value = Strings.table[code]?[key] { return value }
        if let value = Strings.table["en"]?[key] { return value }
        return key
    }
}

enum Strings {
    /// Tabloda olmayan diller İngilizceye düşer; böylece diller tek tek
    /// eklenebilir ve arayüz hiçbir aşamada bozulmaz.
    static let table: [String: [String: String]] = [
        "en": en, "tr": tr, "de": de, "fr": fr, "es": es, "it": it,
        "pt": pt, "nl": nl, "pl": pl, "ru": ru, "ja": ja, "ko": ko
    ]
}