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

// MARK: - Cam yüzey

/// Apple'ın malzeme dilindeki üç katman: bulanık zemin, üstte ince ışık
/// çizgisi, kenarda yukarıdan aşağı sönen gradyan çerçeve. Tek bir düz
/// kenarlık yerine bu üçlü, yüzeye kalınlık hissi verir.
struct GlassSurface: View {
    var cornerRadius: Double = 12
    var tint: Color = .clear
    var intensity: Double = 1.0

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        return shape
            .fill(.ultraThinMaterial)
            // Renk zemini boyamaz, yalnızca üst kenardan içeri sızar; böylece
            // seçili kart renkli bir dikdörtgen değil, ışık almış cam olur.
            .overlay(
                shape.fill(
                    LinearGradient(
                        colors: [tint.opacity(0.20 * intensity),
                                 tint.opacity(0.04 * intensity)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
            )
            .overlay(
                // Kenar ışığı: üstte parlak, altta kaybolur.
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.45 * intensity),
                            .white.opacity(0.08 * intensity),
                            .white.opacity(0.02 * intensity)
                        ],
                        startPoint: .top, endPoint: .bottom
                    ),
                    lineWidth: 1
                )
            )
            .overlay(
                // İç üst kenardaki ince yansıma çizgisi.
                shape
                    .inset(by: 1)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.22 * intensity), .clear],
                            startPoint: .top, endPoint: .center
                        ),
                        lineWidth: 1
                    )
            )
    }
}

// MARK: - Parlama

/// Seçili kartın üzerinden geçen dar ışık bandı. Sabit bir ışık kaynağı
/// varsayıyoruz: kart yelpazede döndüğünde bant kartla birlikte dönmemeli,
/// ekran düzleminde kalmalı. Bunun için kartın açısı kadar ters döndürüyoruz.
struct SpecularSheen: View {
    let cornerRadius: Double
    /// Kartın bulunduğu dizilişteki dönüş açısı (derece).
    var cardAngle: Double = 0
    @State private var phase: Double = -1

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .white.opacity(0.26), location: 0.44),
                        .init(color: .white.opacity(0.42), location: 0.50),
                        .init(color: .white.opacity(0.26), location: 0.56),
                        .init(color: .clear, location: 1)
                    ],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            // İnce bir bant: geniş dikdörtgeni eğip kartın üzerinden geçiriyoruz.
            .rotationEffect(.degrees(28 - cardAngle))
            .scaleEffect(x: 0.55, y: 1.9)
            .blendMode(.plusLighter)
            .opacity(0.75)
            .offset(x: phase * 260)
            .mask(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .onAppear {
                phase = -1
                withAnimation(.easeOut(duration: 0.85)) { phase = 1 }
            }
            .allowsHitTesting(false)
    }
}

// MARK: - Yansıma

/// Cover Flow'un altındaki klasik ayna. Görüntü dikeyde çevrilir ve
/// yukarıdan aşağı sönen bir maskeyle zayıflatılır.
struct Reflection: View {
    let image: CGImage?
    let width: Double
    let height: Double
    let cornerRadius: Double

    var body: some View {
        Group {
            if let image {
                Image(decorative: image, scale: 1, orientation: .up)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .scaleEffect(y: -1, anchor: .center)
                    .mask(
                        LinearGradient(
                            colors: [.white.opacity(0.35), .clear],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .blur(radius: 1.2)
            }
        }
        .frame(width: width, height: height)
        .allowsHitTesting(false)
    }
}

// MARK: - Baskın renk

enum DominantColor {

    private static var cache: [CGWindowID: Color] = [:]

    /// Görüntüyü 1x1'e indirip ortalama rengi okur. Tek piksellik bir çizim,
    /// mikrosaniyeler sürer; sonuç pencere kimliğine göre önbelleklenir.
    static func of(_ image: CGImage, id: CGWindowID) -> Color {
        if let cached = cache[id] { return cached }

        var pixel: [UInt8] = [0, 0, 0, 0]
        let space = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let ctx = CGContext(data: &pixel, width: 1, height: 1,
                                  bitsPerComponent: 8, bytesPerRow: 4,
                                  space: space, bitmapInfo: info) else {
            return .accentColor
        }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))

        var color = Color(.sRGB,
                          red: Double(pixel[0]) / 255,
                          green: Double(pixel[1]) / 255,
                          blue: Double(pixel[2]) / 255)

        // Çok sönük ya da çok soluk renkler vurgu olarak işe yaramaz;
        // doygunluğu ve parlaklığı tabana çekiyoruz.
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .controlAccentColor
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ns.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        if s < 0.12 || b < 0.12 {
            color = .accentColor
        } else {
            color = Color(nsColor: NSColor(hue: h,
                                           saturation: min(max(s, 0.45), 0.9),
                                           brightness: min(max(b, 0.55), 0.95),
                                           alpha: 1))
        }

        cache[id] = color
        if cache.count > 300 { cache.removeAll() }
        return color
    }
}