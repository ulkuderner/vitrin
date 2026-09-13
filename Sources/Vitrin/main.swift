// Vitrin — macOS window-level switcher
// Copyright (C) 2026 Çağlar Ülküderner
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your option)
// any later version. See <https://www.gnu.org/licenses/> for details.
//
// https://github.com/ulkuderner/vitrin

import AppKit

// Menü çubuğu uygulaması: Dock'ta görünmez, pencere açmaz.
// Üst seviye kod ana iş parçacığında çalışır ama Swift 5 kipinde MainActor
// izolasyonuna sahip değildir; @MainActor olan AppDelegate'i kurmak için
// izolasyonu açıkça beyan ediyoruz.
let app = NSApplication.shared
let delegate = MainActor.assumeIsolated { AppDelegate() }
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()