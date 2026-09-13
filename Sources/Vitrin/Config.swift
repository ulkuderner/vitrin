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
import CoreGraphics

/// Kullanıcıya açık olmayan sabitler. Ayarlanabilir olan her şey Settings'te.
enum Config {

    /// Bu uygulamaların pencereleri hiç listelenmez.
    static let ignoredApps: Set<String> = [
        "Vitrin", "Window Server", "Dock", "Notification Center",
        "Control Center", "Spotlight", "loginwindow", "SystemUIServer"
    ]

    /// Bu boyutun altındaki pencereler paletlerdir, atla.
    static let minWindowSize = CGSize(width: 100, height: 60)

    // Sanal tuş kodları
    enum Key {
        static let tab: Int64 = 48
        static let grave: Int64 = 50   // ` (backtick)
        static let escape: Int64 = 53
        static let leftArrow: Int64 = 123
        static let rightArrow: Int64 = 124
        static let downArrow: Int64 = 125
        static let upArrow: Int64 = 126
        static let q: Int64 = 12
        static let w: Int64 = 13
        static let m: Int64 = 46
        static let comma: Int64 = 43
    }
}