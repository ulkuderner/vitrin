// Vitrin — macOS window-level switcher
// Copyright (C) 2026 Çağlar Ülküderner
//
// This program is free software: you can redistribute it and/or modify it
// under the terms of the GNU General Public License as published by the Free
// Software Foundation, either version 3 of the License, or (at your option)
// any later version. See <https://www.gnu.org/licenses/> for details.
//
// https://github.com/ulkuderner/vitrin

import SwiftUI
import AppKit

@MainActor
final class AboutWindowController {

    private var window: NSWindow?

    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let hosting = NSHostingController(rootView: AboutView())
        let w = NSWindow(contentViewController: hosting)
        w.title = ""
        w.styleMask = [.titled, .closable, .fullSizeContentView]
        w.titlebarAppearsTransparent = true
        w.isMovableByWindowBackground = true
        w.isReleasedWhenClosed = false
        w.setContentSize(NSSize(width: 440, height: 560))
        w.center()
        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}

struct AboutView: View {
    @ObservedObject private var settings = Settings.shared

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Vitrin"
    }
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }
    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    var body: some View {
        VStack(spacing: 0) {
            hero
            Divider()
            body_
        }
        .frame(width: 440, height: 560)
        .background(VisualEffect(material: .windowBackground))
    }

    // MARK: Üst blok

    private var hero: some View {
        VStack(spacing: 8) {
            icon
                .padding(.top, 26)
                .padding(.bottom, 6)

            Text(appName)
                .font(.system(size: 26, weight: .semibold))

            Text(L10n.t("about.subtitle"))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Text("\(L10n.t("about.version")) \(version) (\(build))")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.tertiary)
                .padding(.bottom, 10)

            // İmza üst blokta: kaydırmadan görünmeli.
            VStack(spacing: 2) {
                Text(L10n.t("about.author"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                Text("Çağlar Ülküderner")
                    .font(.system(size: 13, weight: .medium))
                    .textSelection(.enabled)
            }
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity)
    }

    /// Paketteki gerçek ikonu gösterir; yoksa sembole düşer.
    @ViewBuilder
    private var icon: some View {
        if let image = NSImage(named: "AppIcon") ?? NSApp.applicationIconImage {
            Image(nsImage: image)
                .resizable()
                .frame(width: 96, height: 96)
                .shadow(color: .black.opacity(0.25), radius: 12, y: 5)
        } else {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 44, weight: .light))
                .frame(width: 96, height: 96)
        }
    }

    // MARK: Alt blok

    private var body_: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                section("about.what", "about.what.body", "sparkles")
                section("about.how", "about.how.body", "gearshape.2")
                section("about.perms", "about.perms.body", "lock.shield")
                section("about.license", "about.license.body", "scale.3d")

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "chevron.left.forwardslash.chevron.right")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 18, height: 18)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.t("about.source"))
                            .font(.system(size: 12, weight: .semibold))
                        Link("github.com/ulkuderner/vitrin",
                             destination: URL(string: "https://github.com/ulkuderner/vitrin")!)
                            .font(.system(size: 12))
                    }
                }

                HStack(spacing: 10) {
                    Button(L10n.t("menu.settings")) {
                        NotificationCenter.default.post(name: .vitrinOpenSettings, object: nil)
                    }
                    Button(L10n.t("about.copy")) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString("\(appName) \(version) (\(build))",
                                                       forType: .string)
                    }
                    Spacer()
                }
                .controlSize(.large)
                .padding(.top, 2)
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func section(_ titleKey: String, _ bodyKey: String, _ symbol: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundStyle(Color.accentColor)
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.t(titleKey))
                    .font(.system(size: 12, weight: .semibold))
                Text(L10n.t(bodyKey))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension Notification.Name {
    static let vitrinOpenSettings = Notification.Name("vitrinOpenSettings")
}