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

/// Hücrelerin ekran üzerindeki çerçevelerini yukarı taşır; uçuş animasyonu
/// başlangıç konumunu buradan öğrenir.
struct CellFrames: PreferenceKey {
    static var defaultValue: [CGWindowID: CGRect] { [:] }
    static func reduce(value: inout [CGWindowID: CGRect], nextValue: () -> [CGWindowID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

@MainActor
final class SwitcherModel: ObservableObject {
    @Published var windows: [WindowInfo] = []
    @Published var selected: Int = 0
    @Published var thumbs: [CGWindowID: CGImage] = [:]
    @Published var sameAppOnly: Bool = false
    @Published var sessionID = UUID()
    /// Fare imlecinin panel merkezine göre normalize konumu (-1…1).
    @Published var pointer: CGPoint = .zero

    var cellFrames: [CGWindowID: CGRect] = [:]
    var iconProvider: (pid_t) -> NSImage? = { _ in nil }
    var onPick: (Int) -> Void = { _ in }

    var current: WindowInfo? {
        windows.indices.contains(selected) ? windows[selected] : nil
    }

    func columns(_ maxColumns: Int) -> Int {
        max(1, min(maxColumns, windows.count))
    }
}

struct SwitcherView: View {
    @ObservedObject var model: SwitcherModel
    @ObservedObject var settings = Settings.shared
    @ObservedObject var access = SystemAccess.shared

    var body: some View {
        VStack(alignment: .leading, spacing: floating ? 14 : 12) {
            header
            content
            if settings.showFooter { footer }
        }
        .padding(floating ? 8 : 18)
        .background(backdrop)
        .clipShape(RoundedRectangle(cornerRadius: floating ? 0 : settings.cornerRadius,
                                    style: .continuous))
        .overlay {
            // Panel zemini yokken çerçeve çizmenin anlamı yok: boşlukta asılı
            // duran ince bir kontur olarak görünür.
            if !floating {
                RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12 * settings.panelOpacity),
                                  lineWidth: 1)
            }
        }
        // Paralaks: tüm panel imlece doğru hafifçe eğilir. Apple TV afişleri gibi.
        // "Hareketi Azalt" açıkken kapalı.
        .rotation3DEffect(.degrees(tilt ? model.pointer.y * 3.0 : 0),
                          axis: (x: 1, y: 0, z: 0), perspective: 0.35)
        .rotation3DEffect(.degrees(tilt ? model.pointer.x * 4.5 : 0),
                          axis: (x: 0, y: 1, z: 0), perspective: 0.35)
        .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.85),
                   value: model.pointer)
        .onPreferenceChange(CellFrames.self) { frames in
            model.cellFrames = frames
        }
        // VoiceOver: panelin tamamı tek bir liste; kartlar öğe.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(L10n.t("switcher.all"))
    }

    private var tilt: Bool { settings.parallax && !access.reduceMotion }

    /// Panel zemini yokken kartlar doğrudan masaüstünde yüzer. Bu durumda
    /// başlık ve ipuçları taşıyacakları bir yüzey bulamaz; kendi kapsüllerini
    /// taşırlar ve ortalanırlar.
    ///
    /// Kullanıcı saydamlığı açıkça sıfıra çektiyse bu karar onundur; sistemin
    /// "Saydamlığı Azalt" tercihi bulanıklığı kaldırır ama paneli geri getirmez.
    private var floating: Bool { settings.panelOpacity < 0.02 }

    /// Taşıyıcı panelin zemini. Saydamlık 0'a inince hiç katman oluşturulmaz.
    /// "Saydamlığı Azalt" açıkken malzeme yerine düz renk kullanılır — aynı
    /// saydamlıkta, ama bulanıklık hesabı yapılmadan.
    @ViewBuilder
    private var backdrop: some View {
        if floating {
            Color.clear
        } else if access.reduceTransparency {
            RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor)
                    .opacity(settings.panelOpacity))
        } else {
            VisualEffect(material: settings.material.material,
                         alpha: settings.panelOpacity)
        }
    }

    // MARK: - Başlık

    private var header: some View {
        HStack(spacing: 10) {
            if floating { Spacer(minLength: 0) }

            HStack(spacing: 10) {
                Text(model.sameAppOnly
                     ? (model.current?.appName ?? L10n.t("switcher.sameApp"))
                     : L10n.t("switcher.all"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Text("\(model.windows.count) \(L10n.t("switcher.count"))")
                    .font(.system(size: 12))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.18), in: Capsule())

                if floating {
                    // Saydam modda başlık, sayaçla aynı kapsülün içinde durur;
                    // sağa yaslamak yerine ortalanır, çünkü tutunacağı bir
                    // panel kenarı yok.
                    Text(model.current?.displayTitle ?? "")
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: 360)
                        .id(model.current?.id ?? 0)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 4)),
                            removal: .opacity))
                        .animation(Motion.title, value: model.selected)
                }
            }
            .modifier(FloatingChip(active: floating, solid: access.reduceTransparency))

            if floating {
                Spacer(minLength: 0)
            } else {
                Spacer()
                Text(model.current?.displayTitle ?? "")
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 420, alignment: .trailing)
                    .id(model.current?.id ?? 0)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 4)),
                        removal: .opacity))
                    .animation(Motion.title, value: model.selected)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - İçerik

    @ViewBuilder
    private var content: some View {
        switch settings.layout {
        case .grid:      gridLayout
        case .filmstrip: carousel(style: .filmstrip)
        case .coverflow: carousel(style: .coverflow)
        case .radial:    carousel(style: .radial)
        case .book:      carousel(style: .book)
        }
    }

    private var gridLayout: some View {
        let count = model.columns(Int(settings.maxColumns))
        let cols = Array(
            repeating: GridItem(.fixed(settings.cellWidth), spacing: 14), count: count)

        return ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: cols, spacing: 14) {
                    ForEach(Array(model.windows.enumerated()), id: \.element.id) { index, window in
                        card(window, index: index)
                            .id(window.id)
                    }
                }
                .padding(4)
                .animation(Motion.select, value: model.selected)
            }
            .frame(maxHeight: settings.maxRows * (settings.thumbHeight + 62))
            .id(model.sessionID)
            .onChange(of: model.selected) { _, _ in
                guard let id = model.current?.id else { return }
                withAnimation(Motion.select) { proxy.scrollTo(id, anchor: .center) }
            }
        }
    }

    /// Şerit, coverflow ve yelpaze aynı iskeleti paylaşır: kartlar seçili
    /// olana göre göreli konumlanır, dönüşümler bu göreli mesafeden türetilir.
    private func carousel(style: LayoutStyle) -> some View {
        let visible = 4     // her iki yanda en fazla bu kadar kart çizilir
        let w = settings.cellWidth

        return ZStack {
            ForEach(Array(model.windows.enumerated()), id: \.element.id) { index, window in
                let rel = Double(index - model.selected)
                if abs(rel) <= Double(visible) {
                    card(window, index: index)
                        .modifier(CarouselTransform(rel: rel, style: style, cellWidth: w))
                        .zIndex(10 - abs(rel))
                }
            }
        }
        .frame(width: min(w * 3.4, 1500),
               height: settings.thumbHeight + (style == .radial ? 210 : 150))
        .id(model.sessionID)
        .animation(Motion.select, value: model.selected)
    }

    private func card(_ window: WindowInfo, index: Int) -> some View {
        let rel = Double(index - model.selected)
        return WindowCard(window: window,
                   index: index,
                   image: model.thumbs[window.id],
                   icon: model.iconProvider(window.pid),
                   isSelected: index == model.selected,
                   depth: abs(rel),
                   // Yelpazede kart döndüğü için parıltı ters döndürülür:
                   // ışık kaynağı ekranda sabit kalır.
                   cardAngle: settings.layout == .radial ? rel * 13.0 : 0,
                   bare: floating,
                   settings: settings)
            .compositingGroup()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(window.appName) — \(window.displayTitle)")
            .accessibilityValue(window.countInApp > 1
                                ? "\(window.indexInApp)/\(window.countInApp)" : "")
            .accessibilityAddTraits(index == model.selected ? [.isSelected, .isButton] : .isButton)
            .onTapGesture { model.onPick(index) }
    }

    // MARK: - Alt bilgi

    private var footer: some View {
        HStack {
            if floating { Spacer(minLength: 0) }
            HStack(spacing: 16) {
                hint("\(settings.trigger.symbol)⇥", L10n.t("hint.forward"))
                hint("⇧", L10n.t("hint.back"))
                hint("\(settings.trigger.symbol)`", L10n.t("hint.sameApp"))
                hint("W", L10n.t("hint.close"))
                hint("M", L10n.t("hint.minimize"))
                hint(",", L10n.t("hint.settings"))
                hint("⎋", L10n.t("hint.cancel"))
            }
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(floating ? .secondary : .tertiary)
            .modifier(FloatingChip(active: floating, solid: access.reduceTransparency))
            if floating { Spacer(minLength: 0) }
        }
        .frame(maxWidth: .infinity)
    }

    private func hint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key).foregroundStyle(.secondary)
            Text(label)
        }
    }
}

// MARK: - Karusel dönüşümü

/// Saydam modda metinlerin taşıyıcı bir panel zemini yoktur; masaüstünün
/// üzerinde okunabilir kalmaları için kendi ince cam kapsüllerini taşırlar.
/// Panel zemini varken kapsül gereksizdir ve devre dışı kalır.
private struct FloatingChip: ViewModifier {
    let active: Bool
    var solid: Bool = false

    func body(content: Content) -> some View {
        if active {
            content
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background {
                    if solid {
                        // "Saydamlığı Azalt" açıkken bulanıklık yerine düz zemin.
                        Capsule().fill(Color(nsColor: .windowBackgroundColor).opacity(0.92))
                    } else {
                        Capsule().fill(.ultraThinMaterial)
                    }
                }
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                )
        } else {
            content
        }
    }
}

/// Kartın seçili olana göre mesafesinden konum, dönüş ve ölçek üretir.
/// Üç biçim de aynı matematikten besleniyor, yalnızca katsayılar değişiyor.
private struct CarouselTransform: ViewModifier {
    let rel: Double
    let style: LayoutStyle
    let cellWidth: Double

    func body(content: Content) -> some View {
        switch style {
        case .filmstrip:
            content
                .scaleEffect(rel == 0 ? 1.0 : 0.84)
                .offset(x: rel * cellWidth * 0.92)
                .opacity(fade)

        case .coverflow:
            content
                .scaleEffect(1 - min(abs(rel) * 0.10, 0.34))
                .rotation3DEffect(
                    .degrees(-max(min(rel * 34, 62), -62)),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.55
                )
                .offset(x: rel * cellWidth * 0.52)
                .opacity(fade)

        case .radial:
            // Kartlar merkezli bir yay üzerinde; açı arttıkça aşağı iner.
            let angle = rel * 13.0
            let radians = angle * .pi / 180
            let radius = cellWidth * 1.9
            content
                .scaleEffect(1 - min(abs(rel) * 0.07, 0.25))
                .rotationEffect(.degrees(angle))
                .offset(x: sin(radians) * radius,
                        y: (1 - cos(radians)) * radius * 0.9)
                .opacity(fade)

        case .book:
            // Sayfa çevirme: geçilenler sol kapağa düşer, sıradakiler sağda bekler.
            // Seçili sayfa düz durur; komşular kendi cilt kenarından açılır.
            let turned = rel < 0
            let amount = min(abs(rel), 3)
            content
                .rotation3DEffect(
                    .degrees(turned ? -70 - amount * 6 : min(rel * 26, 74)),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: turned ? .leading : .trailing,
                    perspective: 0.85
                )
                .offset(x: turned ? -cellWidth * (0.34 + amount * 0.05)
                                  : cellWidth * min(rel * 0.30, 0.95))
                .brightness(turned ? -0.10 : 0)
                .opacity(fade)

        case .grid:
            content
        }
    }

    private var fade: Double {
        max(0, 1 - abs(rel) * 0.22)
    }
}

// MARK: - Kart

// MARK: - Giriş dönüşümü

/// Kartın sahneye giriş biçimi. Katlanma, katlanabilir telefonun açılmasını
/// taklit eder: kart sol kenarından menteleliymiş gibi düzleşir.
private struct EntranceTransform: ViewModifier {
    let shown: Bool
    let style: EntranceStyle

    func body(content: Content) -> some View {
        switch style {
        case .rise:
            content
                .scaleEffect(shown ? 1 : 0.94)
                .offset(y: shown ? 0 : 10)

        case .fold:
            content
                .rotation3DEffect(.degrees(shown ? 0 : -78),
                                  axis: (x: 0, y: 1, z: 0),
                                  anchor: .leading,
                                  perspective: 0.7)
                .offset(x: shown ? 0 : -8)

        case .flip:
            content
                .rotation3DEffect(.degrees(shown ? 0 : 68),
                                  axis: (x: 1, y: 0, z: 0),
                                  anchor: .bottom,
                                  perspective: 0.6)
                .scaleEffect(shown ? 1 : 0.96)
        }
    }
}

private struct WindowCard: View {
    let window: WindowInfo
    let index: Int
    let image: CGImage?
    let icon: NSImage?
    let isSelected: Bool
    let depth: Double        // seçiliye göre mesafe; derinlik bulanıklığını belirler
    let cardAngle: Double    // dizilişteki dönüş açısı; parıltı bunu telafi eder
    /// Panel zemini yokken kart kendi yüzeyini taşımaz: küçük resmin kendisi
    /// karttır. Aksi halde görüntünün çevresinde ince bir cam halka kalır ve
    /// üst üste binen kartlarda bu halkalar tek bir kontur gibi okunur.
    let bare: Bool
    @ObservedObject var settings: Settings
    @ObservedObject private var access = SystemAccess.shared

    @State private var shown = false
    @State private var hovered = false

    /// Küçük resmin baskın rengi; parıltı ve cam tonu bundan beslenir.
    private var tint: Color {
        guard settings.tintGlow, let image else { return .accentColor }
        return DominantColor.of(image, id: window.id)
    }

    /// Girişte buzlu camdan bakıyormuş gibi başlayıp netleşir; ayrıca seçili
    /// olmayan kartlar mesafeyle orantılı olarak alan derinliğine düşer.
    private var blurRadius: Double {
        guard !access.reduceTransparency else { return 0 }
        var r = 0.0
        if settings.frostedEntrance && !shown { r += settings.frostStrength }
        if settings.depthBlur && !isSelected { r += min(depth * 1.1, 3.4) }
        return r
    }

    /// Yüzeysiz kartta gölge yalnızca seçili olana ait.
    private var shadowColor: Color {
        if isSelected { return .black.opacity(0.32) }
        return bare ? .clear : .black.opacity(0.16)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            thumbnail
            if settings.showTitles { caption }
        }
        .padding(bare ? 0 : 8)
        .background(background)
        // Hâle iki katman: dar ve yoğun bir çekirdek, geniş ve çok soluk bir
        // yayılma. Tek bir gölge ya sert bir halka ya da bulanık bir leke olur;
        // ikisi üst üste gelince ışığın kaynağı varmış gibi durur.
        .shadow(color: (isSelected && settings.glow) ? tint.opacity(0.30) : .clear,
                radius: (isSelected && settings.glow) ? 9 : 0)
        .shadow(color: (isSelected && settings.glow) ? tint.opacity(0.16) : .clear,
                radius: (isSelected && settings.glow) ? 30 : 0)
        // Yükseklik gölgesi ayrı: renk değil derinlik taşır. Yüzeyi olmayan
        // kartlarda yalnızca seçili olan gölge düşürür; aksi halde üst üste
        // binen kartların gölgeleri birleşip karusel çerçevesi kadar bir
        // bulut oluşturuyor ve kenarında kontur gibi bir sınır bırakıyor.
        .shadow(color: shadowColor,
                radius: isSelected ? 24 : (bare ? 0 : 9),
                y: isSelected ? 11 : (bare ? 0 : 4))
        .scaleEffect(isSelected ? 1.035 : (hovered ? 1.015 : 1.0))
        .opacity(shown ? 1 : 0)
        .modifier(EntranceTransform(shown: shown,
                                    style: access.reduceMotion ? .rise : settings.entrance))
        .blur(radius: blurRadius)
        .background(frameReporter)
        // Fareyle üzerine gelince kart hafifçe kalkar: tıklanabilir olduğunu
        // imleç oraya varır varmaz söyler.
        .onHover { inside in
            withAnimation(.easeOut(duration: 0.14)) { hovered = inside }
        }
        .onAppear {
            // Gecikme, listenin başından değil seçili karttan yayılır: göz
            // zaten oraya bakıyor, dalga oradan dışarı açılmalı.
            let wave = Int(depth.rounded())
            withAnimation(Motion.appear.delay(Motion.staggerDelay(wave))) { shown = true }
        }
    }

    @ViewBuilder
    private var background: some View {
        ZStack {
            if bare {
                // Yüzey yok: görüntü kendi başına durur.
                Color.clear
            } else if settings.glassCards && !access.reduceTransparency {
                GlassSurface(cornerRadius: 14,
                             tint: isSelected ? tint : .clear,
                             intensity: isSelected ? 1.0 : 0.55)
            } else {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(access.reduceTransparency
                          ? Color(nsColor: .controlBackgroundColor)
                          : Color.white.opacity(0.05))
            }

            if isSelected {
                // Seçim, doygun bir halka yerine iki katmanlı ışıkla anlatılır:
                // içeriden dışarı sönen yumuşak bir hâle ve kenarda saç teli
                // kalınlığında, üstte parlak altta kaybolan bir ışık çizgisi.
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [tint.opacity(0.95), tint.opacity(0.35)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: access.increaseContrast ? 3 : 1
                    )
                    .blur(radius: access.increaseContrast ? 0 : 0.3)

                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.5), lineWidth: 0.5)
                    .blendMode(.plusLighter)

                if settings.sheen && !access.reduceMotion {
                    SpecularSheen(cornerRadius: 14, cardAngle: cardAngle)
                        .id(window.id)   // seçim değiştikçe bir kez süzülsün
                }
            }
        }
    }

    private var thumbnail: some View {
        // İç yarıçap eşmerkezli olmalı: dış 14, kenar boşluğu 8 → iç 6.
        // Eşit yarıçap kullanmak kartın içindeki köşeleri dışarıdakinden daha
        // sivri gösterir; Apple'ın her yerde uyguladığı kural budur.
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.black.opacity(0.22))

            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 56, height: 56)
                    .opacity(image == nil ? (window.isMinimized ? 0.45 : 0.8) : 0)
            }

            if let image {
                // Sığdırmak yerine doldurup üstten kırpıyoruz: pencere
                // görüntülerinde bilgi üstte olur ve kutu payı bırakmak
                // kartı boş gösterir.
                Image(decorative: image, scale: 1, orientation: .up)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: settings.cellWidth, height: settings.thumbHeight,
                           alignment: .top)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }

            if window.isMinimized {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "minus.rectangle.fill")
                            .foregroundStyle(.secondary)
                            .padding(6)
                    }
                }
            }
        }
        .frame(width: settings.cellWidth, height: settings.thumbHeight)
        .overlay(alignment: .bottom) {
            if settings.reflections && settings.layout.isCarousel {
                Reflection(image: image,
                           width: settings.cellWidth,
                           height: settings.thumbHeight * 0.42,
                           cornerRadius: 8)
                    .offset(y: settings.thumbHeight * 0.42 + 2)
            }
        }
        .animation(Motion.thumb, value: image != nil)
    }

    private var caption: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(nsImage: icon).resizable().frame(width: 16, height: 16)
            }
            Text(window.displayTitle)
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 4)
            if window.countInApp > 1 {
                Text("\(window.indexInApp)/\(window.countInApp)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(isSelected ? tint : .secondary)
            }
        }
        .frame(width: settings.cellWidth, alignment: .leading)
        // Kart yüzeyi yokken metin doğrudan masaüstünün üzerinde durur;
        // ince bir gölge her zeminde okunur kalmasını sağlar.
        .shadow(color: bare ? .black.opacity(0.75) : .clear, radius: 3, y: 1)
    }

    private var frameReporter: some View {
        GeometryReader { geo in
            Color.clear.preference(key: CellFrames.self,
                                   value: [window.id: geo.frame(in: .global)])
        }
    }
}

struct VisualEffect: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    var alpha: Double = 1.0

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        view.alphaValue = alpha
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.alphaValue = alpha
    }
}