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
import Combine

/// Sistem erişilebilirlik tercihlerini izler. Apple'ın kalite çıtasında bir
/// uygulama bunlara uymak zorundadır: "Hareketi Azalt" açıkken yay
/// animasyonları ve uçuş kapanır, "Saydamlığı Azalt" açıkken malzeme
/// katmanları düz zemine döner, "Kontrastı Artır" açıkken kenarlar belirginleşir.
@MainActor
final class SystemAccess: ObservableObject {

    static let shared = SystemAccess()

    @Published private(set) var reduceMotion = false
    @Published private(set) var reduceTransparency = false
    @Published private(set) var increaseContrast = false

    private var observers: [NSObjectProtocol] = []

    private init() {
        refresh()
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        })
    }

    private func refresh() {
        let a = NSWorkspace.shared
        reduceMotion = a.accessibilityDisplayShouldReduceMotion
        reduceTransparency = a.accessibilityDisplayShouldReduceTransparency
        increaseContrast = a.accessibilityDisplayShouldIncreaseContrast
    }
}