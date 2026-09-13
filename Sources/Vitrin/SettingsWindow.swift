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
final class SettingsWindowController {

    private var window: NSWindow?

    func show() {
        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let hosting = NSHostingController(rootView: SettingsView())
        let w = NSWindow(contentViewController: hosting)
        w.title = "Vitrin"
        w.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        w.titlebarAppearsTransparent = true
        w.isReleasedWhenClosed = false
        // NSHostingController pencereyi kendi ölçüsüyle açıyor ve SwiftUI'deki
        // frame'i dikkate almayabiliyor; içerik alttan kırpılmasın diye boyutu
        // açıkça veriyoruz.
        w.setContentSize(NSSize(width: 720, height: 560))
        w.minSize = NSSize(width: 680, height: 460)
        w.center()
        window = w
        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Bölümler

private enum Pane: String, CaseIterable, Identifiable {
    case general, appearance, motion, glass, transition, about
    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .general:    return "tab.general"
        case .appearance: return "tab.appearance"
        case .motion:     return "tab.motion"
        case .glass:      return "tab.glass"
        case .transition: return "tab.transition"
        case .about:      return "tab.about"
        }
    }

    var symbol: String {
        switch self {
        case .general:    return "gearshape.fill"
        case .appearance: return "rectangle.3.group.fill"
        case .motion:     return "wand.and.stars"
        case .glass:      return "square.on.square.dashed"
        case .transition: return "arrow.left.arrow.right"
        case .about:      return "info"
        }
    }

    var color: Color {
        switch self {
        case .general:    return .gray
        case .appearance: return .blue
        case .motion:     return .purple
        case .glass:      return .teal
        case .transition: return .orange
        case .about:      return .indigo
        }
    }
}

// MARK: - Kök görünüm

struct SettingsView: View {
    @ObservedObject private var settings = Settings.shared
    @State private var pane: Pane = .general
    @State private var launchAtLogin = false

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
        }
        .frame(minWidth: 680, minHeight: 460)
        .background(VisualEffect(material: .windowBackground))
    }

    // MARK: Kenar çubuğu

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(LinearGradient(colors: [.accentColor, .accentColor.opacity(0.55)],
                                             startPoint: .top, endPoint: .bottom))
                        .frame(width: 30, height: 30)
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("Vitrin").font(.system(size: 14, weight: .semibold))
                    Text(L10n.t("about.subtitle"))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 34)
            .padding(.bottom, 16)

            ForEach(Pane.allCases) { item in
                sidebarRow(item)
            }

            Spacer()
        }
        .frame(width: 208)
        .background(VisualEffect(material: .sidebar))
    }

    private func sidebarRow(_ item: Pane) -> some View {
        let active = pane == item
        return Button {
            pane = item
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(item.color.gradient)
                        .frame(width: 22, height: 22)
                    Image(systemName: item.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text(L10n.t(item.titleKey))
                    .font(.system(size: 13))
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(active ? Color.accentColor.opacity(0.85) : .clear)
            )
            .foregroundStyle(active ? Color.white : Color.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    // MARK: Detay

    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(L10n.t(pane.titleKey))
                    .font(.system(size: 20, weight: .semibold))
                    .padding(.bottom, -4)

                switch pane {
                case .general:    generalPane
                case .appearance: appearancePane
                case .motion:     motionPane
                case .glass:      glassPane
                case .transition: transitionPane
                case .about:      aboutPane
                }

                if pane != .about {
                    HStack {
                        Button(L10n.t("common.preview")) { settings.onPreview?() }
                            .controlSize(.large)
                        Spacer()
                        Button(L10n.t("common.reset")) { settings.resetToDefaults() }
                            .controlSize(.large)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 34)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: Hakkında

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Vitrin"
    }
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.0"
    }
    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    private var aboutPane: some View {
        VStack(spacing: 14) {
            Card {
                HStack(spacing: 14) {
                    if let image = NSApp.applicationIconImage {
                        Image(nsImage: image)
                            .resizable()
                            .frame(width: 64, height: 64)
                            .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(appName).font(.system(size: 20, weight: .semibold))
                        Text(L10n.t("about.subtitle"))
                            .font(.system(size: 12)).foregroundStyle(.secondary)
                        Text("\(L10n.t("about.version")) \(version) (\(build))")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
            }

            Card {
                Text(L10n.t("about.author"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                Text("Çağlar Ülküderner")
                    .font(.system(size: 14, weight: .medium))
                    .textSelection(.enabled)
            }

            Card {
                aboutRow("about.what", "about.what.body", "sparkles")
                Divider()
                aboutRow("about.how", "about.how.body", "gearshape.2")
                Divider()
                aboutRow("about.perms", "about.perms.body", "lock.shield")
            }

            HStack {
                Button(L10n.t("about.copy")) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString("\(appName) \(version) (\(build))",
                                                   forType: .string)
                }
                .controlSize(.large)
                Spacer()
            }
        }
    }

    private func aboutRow(_ titleKey: String, _ bodyKey: String, _ symbol: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundStyle(Color.accentColor)
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(L10n.t(titleKey)).font(.system(size: 12, weight: .semibold))
                Note(L10n.t(bodyKey))
            }
        }
    }

    // MARK: Genel

    private var generalPane: some View {
        VStack(spacing: 14) {
            Card {
                Picker(L10n.t("general.trigger"), selection: $settings.trigger) {
                    ForEach(TriggerKey.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Note(L10n.t("general.trigger.note"))

                Picker(L10n.t("general.language"), selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { Text($0.label).tag($0) }
                }
            }

            Card {
                // Login item durumu sistemden okunuyor ve gözlemlenebilir
                // değil; yerel duruma bağlamazsak anahtar tıklandığı anda
                // güncellenmez, ancak görünüm yeniden kurulunca belirir.
                Toggle(L10n.t("general.login"), isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, wants in
                        LoginItem.set(wants)
                        // Kayıt reddedilmiş olabilir; gerçek durumu geri okuyup
                        // anahtarı sistemle aynı hizaya getiriyoruz.
                        let actual = LoginItem.isEnabled
                        if actual != wants { launchAtLogin = actual }
                    }
                Note(loginNote)
            }
            .onAppear { launchAtLogin = LoginItem.isEnabled }

            Card {
                Toggle(L10n.t("general.minimized"), isOn: $settings.includeMinimized)
                Toggle(L10n.t("general.titles"), isOn: $settings.showTitles)
                Toggle(L10n.t("general.footer"), isOn: $settings.showFooter)
            }

            Card {
                Toggle(L10n.t("general.icon"), isOn: Binding(
                    get: { settings.showStatusIcon },
                    set: { wants in
                        if wants { settings.showStatusIcon = true } else { askHideIcon() }
                    }
                ))
                Note(L10n.t("general.icon.note"))
            }

            // Çıkış yalnızca menü çubuğu ikonu gizliyken burada durur; ikon
            // açıkken menüde zaten "Çık" var ve iki ayrı yol gereksiz.
            // Kenar çubuğunda değil, en altta ve onaylı: gezinirken yanlışlıkla
            // tıklanacak bir yerde olmamalı.
            if !settings.showStatusIcon {
                Card {
                    Button(role: .destructive) {
                        confirmQuit()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "power")
                            Text(L10n.t("common.quit"))
                        }
                    }
                    .controlSize(.large)
                }
            }
        }
    }

    /// Çıkışı onaya bağlıyoruz; tek tıkla kapanan bir düğme ayar penceresinde
    /// olmamalı.
    private func confirmQuit() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = L10n.t("quit.title")
            alert.informativeText = L10n.t("quit.body")
            alert.addButton(withTitle: L10n.t("common.quit"))
            alert.addButton(withTitle: L10n.t("common.cancel"))
            if alert.runModal() == .alertFirstButtonReturn {
                NSApp.terminate(nil)
            }
        }
    }

    /// macOS bazı durumlarda kaydı kullanıcı onayına bırakır; o zaman anahtar
    /// açık görünse de uygulama açılışta başlamaz. Bunu sessizce geçmiyoruz.
    private var loginNote: String {
        LoginItem.requiresApproval
            ? L10n.t("general.login.approval")
            : L10n.t("general.login.note")
    }

    /// Modal uyarıyı görünüm güncellemesinin dışına atıyoruz; SwiftUI binding
    /// setter'ı içinden modal döngü başlatmak yeniden giriş hatasına yol açar.
    private func askHideIcon() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = L10n.t("general.hide.title")
            alert.informativeText = L10n.t("general.hide.body")
            alert.addButton(withTitle: L10n.t("general.hide.ok"))
            alert.addButton(withTitle: L10n.t("common.cancel"))
            if alert.runModal() == .alertFirstButtonReturn {
                Settings.shared.showStatusIcon = false
            }
        }
    }

    // MARK: Görünüm

    private var appearancePane: some View {
        VStack(spacing: 14) {
            Card {
                Picker(L10n.t("appearance.layout"), selection: $settings.layout) {
                    ForEach(LayoutStyle.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Note(settings.layout.note)
            }

            Card {
                Picker(L10n.t("appearance.entrance"), selection: $settings.entrance) {
                    ForEach(EntranceStyle.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Note(settings.entrance.note)
            }

            Card {
                Slid(L10n.t("appearance.cellWidth"), $settings.cellWidth, 150...460, 10, "%.0f pt")
                Slid(L10n.t("appearance.thumbHeight"), $settings.thumbHeight, 90...320, 10, "%.0f pt")
                if settings.layout == .grid {
                    Slid(L10n.t("appearance.columns"), $settings.maxColumns, 2...8, 1, "%.0f")
                    Slid(L10n.t("appearance.rows"), $settings.maxRows, 1...6, 1, "%.0f")
                }
            }

            Card {
                Picker(L10n.t("appearance.material"), selection: $settings.material) {
                    ForEach(PanelMaterial.allCases) { Text($0.label).tag($0) }
                }
                .disabled(settings.panelOpacity < 0.02)
                Slid(L10n.t("appearance.opacity"), $settings.panelOpacity, 0...1, 0.05, "%.2f")
                Note(opacityNote)
                Toggle(L10n.t("appearance.shadow"), isOn: $settings.panelShadow)
                    .disabled(settings.panelOpacity < 0.02)
                Slid(L10n.t("appearance.corner"), $settings.cornerRadius, 0...36, 1, "%.0f pt")
            }
        }
    }

    private var opacityNote: String {
        let v = settings.panelOpacity
        if v < 0.02 { return L10n.t("appearance.op.zero") }
        if v < 0.6 { return L10n.t("appearance.op.mid") }
        return L10n.t("appearance.op.full")
    }

    // MARK: Hareket

    private var motionPane: some View {
        VStack(spacing: 14) {
            Card {
                Picker(L10n.t("motion.character"), selection: $settings.motion) {
                    ForEach(MotionStyle.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                Note(motionNote)
            }
            Card {
                Toggle(L10n.t("motion.stagger"), isOn: $settings.staggered)
                Toggle(L10n.t("motion.glow"), isOn: $settings.glow)
                Toggle(L10n.t("motion.flight"), isOn: $settings.flight)
            }
        }
    }

    private var motionNote: String {
        switch settings.motion {
        case .none:     return L10n.t("motion.n.none")
        case .snappy:   return L10n.t("motion.n.snappy")
        case .spring:   return L10n.t("motion.n.spring")
        case .smooth:   return L10n.t("motion.n.smooth")
        case .dramatic: return L10n.t("motion.n.dramatic")
        }
    }

    // MARK: Cam

    private var glassPane: some View {
        VStack(spacing: 14) {
            Card {
                Toggle(L10n.t("glass.frosted"), isOn: $settings.frostedEntrance)
                Note(L10n.t("glass.frosted.note"))
                if settings.frostedEntrance {
                    Slid(L10n.t("glass.strength"), $settings.frostStrength, 4...30, 1, "%.0f pt")
                }
            }
            Card {
                Toggle(L10n.t("glass.cards"), isOn: $settings.glassCards)
                Toggle(L10n.t("glass.depth"), isOn: $settings.depthBlur)
                Note(L10n.t("glass.depth.note"))
                Toggle(L10n.t("glass.sheen"), isOn: $settings.sheen)
                Toggle(L10n.t("glass.reflection"), isOn: $settings.reflections)
            }
            Card {
                Toggle(L10n.t("glass.tint"), isOn: $settings.tintGlow)
                Note(L10n.t("glass.tint.note"))
            }
        }
    }

    // MARK: Geçiş

    private var transitionPane: some View {
        VStack(spacing: 14) {
            Card {
                Toggle(L10n.t("transition.scrim"), isOn: $settings.scrim)
                if settings.scrim {
                    Slid(L10n.t("transition.dim"), $settings.scrimDim, 0...0.8, 0.02, "%.2f")
                    Toggle(L10n.t("transition.blur"), isOn: $settings.scrimBlur)
                    Note(L10n.t("transition.scrim.note"))
                }
            }
            Card {
                Toggle(L10n.t("motion.flight"), isOn: $settings.flight)
                Toggle(L10n.t("transition.pulse"), isOn: $settings.arrivalPulse)
                Note(L10n.t("transition.pulse.note"))
                Toggle(L10n.t("transition.collapse"), isOn: $settings.collapseToSelection)
            }
            Card {
                Toggle(L10n.t("transition.parallax"), isOn: $settings.parallax)
                Note(L10n.t("transition.parallax.note"))
            }
        }
    }
}

// MARK: - Küçük yapı taşları

/// Ayar grubu: yuvarlak köşeli, hafif zeminli kart.
private struct Card<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
        )
    }
}

private struct Note: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct Slid: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: String

    init(_ title: String, _ value: Binding<Double>,
         _ range: ClosedRange<Double>, _ step: Double, _ format: String) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.format = format
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title).font(.system(size: 12))
                Spacer()
                Text(String(format: format, value))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Slider(value: $value, in: range, step: step)
        }
    }
}