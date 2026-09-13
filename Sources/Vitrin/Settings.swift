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

/// Kullanıcı ayarları. Tümü UserDefaults'ta saklanır, değişiklik anında
/// yayınlanır; bir sonraki ⌘Tab oturumunda geçerli olur.
@MainActor
final class Settings: ObservableObject {

    static let shared = Settings()

    // MARK: - Kısayol

    @Published var trigger: TriggerKey = .command { didSet { save(trigger.rawValue, "trigger") } }
    @Published var includeMinimized = true { didSet { save(includeMinimized, "includeMinimized") } }
    /// Menü çubuğu ikonu. Kapalıyken ayarlara üç yoldan ulaşılır: anahtarlayıcı
    /// açıkken virgül tuşu, Finder'dan uygulamayı yeniden açmak, ya da terminalden
    /// `open -a Vitrin`.
    @Published var showStatusIcon = true { didSet { save(showStatusIcon, "showStatusIcon") } }
    @Published var language: AppLanguage = .system { didSet { save(language.rawValue, "language") } }

    // MARK: - Boyut

    @Published var cellWidth: Double = 260 { didSet { save(cellWidth, "cellWidth") } }
    @Published var thumbHeight: Double = 150 { didSet { save(thumbHeight, "thumbHeight") } }
    @Published var maxColumns: Double = 5 { didSet { save(maxColumns, "maxColumns") } }
    @Published var maxRows: Double = 3 { didSet { save(maxRows, "maxRows") } }

    // MARK: - Gösterim

    @Published var layout: LayoutStyle = .grid { didSet { save(layout.rawValue, "layout") } }
    @Published var entrance: EntranceStyle = .rise { didSet { save(entrance.rawValue, "entrance") } }
    @Published var material: PanelMaterial = .hud { didSet { save(material.rawValue, "material") } }
    /// Varsayılan: panel saydam, arka plan bulanık. Cam kartlar doğrudan
    /// bulanıklaşmış masaüstünün üzerinde yüzer.
    @Published var panelOpacity: Double = 0.0 { didSet { save(panelOpacity, "panelOpacity") } }
    @Published var panelShadow = false { didSet { save(panelShadow, "panelShadow") } }
    @Published var cornerRadius: Double = 22 { didSet { save(cornerRadius, "cornerRadius") } }
    @Published var showTitles = true { didSet { save(showTitles, "showTitles") } }
    @Published var showFooter = true { didSet { save(showFooter, "showFooter") } }

    // MARK: - Hareket

    @Published var motion: MotionStyle = .spring { didSet { save(motion.rawValue, "motion") } }
    @Published var staggered = true { didSet { save(staggered, "staggered") } }
    @Published var flight = true { didSet { save(flight, "flight") } }
    @Published var glow = true { didSet { save(glow, "glow") } }

    // MARK: - Cam ve derinlik

    @Published var glassCards = true { didSet { save(glassCards, "glassCards") } }
    @Published var frostedEntrance = true { didSet { save(frostedEntrance, "frostedEntrance") } }
    @Published var depthBlur = true { didSet { save(depthBlur, "depthBlur") } }
    @Published var sheen = true { didSet { save(sheen, "sheen") } }
    @Published var reflections = true { didSet { save(reflections, "reflections") } }
    @Published var tintGlow = true { didSet { save(tintGlow, "tintGlow") } }
    @Published var frostStrength: Double = 14 { didSet { save(frostStrength, "frostStrength") } }

    // MARK: - Arka plan ve geçiş

    /// Anahtarlayıcı açıkken masaüstünü karartıp bulanıklaştıran katman.
    @Published var scrim = true { didSet { save(scrim, "scrim") } }
    @Published var scrimDim: Double = 0.22 { didSet { save(scrimDim, "scrimDim") } }
    @Published var scrimBlur = true { didSet { save(scrimBlur, "scrimBlur") } }
    /// Seçilen pencerenin çevresinde bir kez atan ışıklı çerçeve.
    @Published var arrivalPulse = true { didSet { save(arrivalPulse, "arrivalPulse") } }
    /// Panel kapanırken seçili kartın üzerine büzülsün.
    @Published var collapseToSelection = true { didSet { save(collapseToSelection, "collapseToSelection") } }
    /// Fare hareketiyle kartlar hafifçe eğilsin.
    @Published var parallax = true { didSet { save(parallax, "parallax") } }

    /// Önizleme düğmesi; AppDelegate bağlar.
    var onPreview: (() -> Void)?

    // MARK: - Türetilmiş

    var capturePixelWidth: Int { Int(cellWidth * 2.2) }

    private let d = UserDefaults.standard
    private var loaded = false

    private init() {
        if let v = d.string(forKey: "trigger"), let t = TriggerKey(rawValue: v) { trigger = t }
        if let v = d.string(forKey: "language"), let l = AppLanguage(rawValue: v) { language = l }
        if let v = d.string(forKey: "layout"), let l = LayoutStyle(rawValue: v) { layout = l }
        if let v = d.string(forKey: "entrance"), let e = EntranceStyle(rawValue: v) { entrance = e }
        if let v = d.string(forKey: "motion"), let m = MotionStyle(rawValue: v) { motion = m }
        if let v = d.string(forKey: "material"), let m = PanelMaterial(rawValue: v) { material = m }
        if d.object(forKey: "includeMinimized") != nil { includeMinimized = d.bool(forKey: "includeMinimized") }
        if d.object(forKey: "showStatusIcon") != nil { showStatusIcon = d.bool(forKey: "showStatusIcon") }
        if d.object(forKey: "showTitles") != nil { showTitles = d.bool(forKey: "showTitles") }
        if d.object(forKey: "showFooter") != nil { showFooter = d.bool(forKey: "showFooter") }
        if d.object(forKey: "staggered") != nil { staggered = d.bool(forKey: "staggered") }
        if d.object(forKey: "flight") != nil { flight = d.bool(forKey: "flight") }
        if d.object(forKey: "glow") != nil { glow = d.bool(forKey: "glow") }
        if d.object(forKey: "glassCards") != nil { glassCards = d.bool(forKey: "glassCards") }
        if d.object(forKey: "frostedEntrance") != nil { frostedEntrance = d.bool(forKey: "frostedEntrance") }
        if d.object(forKey: "depthBlur") != nil { depthBlur = d.bool(forKey: "depthBlur") }
        if d.object(forKey: "sheen") != nil { sheen = d.bool(forKey: "sheen") }
        if d.object(forKey: "reflections") != nil { reflections = d.bool(forKey: "reflections") }
        if d.object(forKey: "tintGlow") != nil { tintGlow = d.bool(forKey: "tintGlow") }
        if let v = d.object(forKey: "frostStrength") as? Double { frostStrength = v }
        if let v = d.object(forKey: "panelOpacity") as? Double { panelOpacity = v }
        if d.object(forKey: "panelShadow") != nil { panelShadow = d.bool(forKey: "panelShadow") }
        if d.object(forKey: "scrim") != nil { scrim = d.bool(forKey: "scrim") }
        if d.object(forKey: "scrimBlur") != nil { scrimBlur = d.bool(forKey: "scrimBlur") }
        if d.object(forKey: "arrivalPulse") != nil { arrivalPulse = d.bool(forKey: "arrivalPulse") }
        if d.object(forKey: "collapseToSelection") != nil { collapseToSelection = d.bool(forKey: "collapseToSelection") }
        if d.object(forKey: "parallax") != nil { parallax = d.bool(forKey: "parallax") }
        if let v = d.object(forKey: "scrimDim") as? Double { scrimDim = v }
        if let v = d.object(forKey: "cellWidth") as? Double { cellWidth = v }
        if let v = d.object(forKey: "thumbHeight") as? Double { thumbHeight = v }
        if let v = d.object(forKey: "maxColumns") as? Double { maxColumns = v }
        if let v = d.object(forKey: "maxRows") as? Double { maxRows = v }
        loaded = true
    }

    private func save(_ value: Any, _ key: String) {
        guard loaded else { return }   // init sırasında geri yazma
        d.set(value, forKey: key)
    }

    func resetToDefaults() {
        trigger = .command; includeMinimized = true; showStatusIcon = true; language = .system
        cellWidth = 260; thumbHeight = 150; maxColumns = 5; maxRows = 3
        layout = .grid; material = .hud; cornerRadius = 22
        entrance = .rise
        panelOpacity = 0.0; panelShadow = false
        showTitles = true; showFooter = true
        motion = .spring; staggered = true; flight = true; glow = true
        glassCards = true; frostedEntrance = true; depthBlur = true
        sheen = true; reflections = true; tintGlow = true; frostStrength = 14
        scrim = true; scrimDim = 0.22; scrimBlur = true
        arrivalPulse = true; collapseToSelection = true; parallax = true
    }
}