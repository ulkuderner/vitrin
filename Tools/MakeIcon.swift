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
import CoreGraphics
import Foundation

// Uygulama ikonunu üretir. Elle çizilmiş bir PNG yerine kod: renk, açı ve
// yuvarlaklık tek yerden ayarlanır, her boyut aynı kaynaktan yeniden üretilir.
//
// Kullanım:  swift Tools/MakeIcon.swift <cikti-klasoru>

let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "./Icon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func rounded(_ r: CGRect, _ rad: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)
}

func drawIcon(size S: CGFloat) -> CGImage? {
    let cs = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(data: nil, width: Int(S), height: Int(S),
                              bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }

    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high

    // macOS ikon ızgarası: gövde tuvalin ~%82'si, ortalanmış.
    let inset = S * 0.09
    let body = CGRect(x: inset, y: inset, width: S - inset * 2, height: S - inset * 2)
    let radius = body.width * 0.2237

    // Gövde gölgesi
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -S * 0.012), blur: S * 0.045,
                  color: NSColor.black.withAlphaComponent(0.35).cgColor)
    ctx.addPath(rounded(body, radius))
    ctx.setFillColor(NSColor.black.cgColor)
    ctx.fillPath()
    ctx.restoreGState()

    // Gövde: derin lacivertten mora
    ctx.saveGState()
    ctx.addPath(rounded(body, radius))
    ctx.clip()
    let top = NSColor(srgbRed: 0.36, green: 0.30, blue: 0.92, alpha: 1).cgColor
    let bottom = NSColor(srgbRed: 0.13, green: 0.10, blue: 0.38, alpha: 1).cgColor
    if let g = CGGradient(colorsSpace: cs, colors: [top, bottom] as CFArray, locations: [0, 1]) {
        ctx.drawLinearGradient(g, start: CGPoint(x: body.midX, y: body.maxY),
                               end: CGPoint(x: body.midX, y: body.minY), options: [])
    }
    if let g = CGGradient(colorsSpace: cs,
                          colors: [NSColor.white.withAlphaComponent(0.22).cgColor,
                                   NSColor.white.withAlphaComponent(0).cgColor] as CFArray,
                          locations: [0, 1]) {
        ctx.drawRadialGradient(g, startCenter: CGPoint(x: body.midX, y: body.maxY),
                               startRadius: 0,
                               endCenter: CGPoint(x: body.midX, y: body.maxY),
                               endRadius: body.width * 0.85, options: [])
    }

    // Üst üste binmiş cam kartlar
    let cardW = body.width * 0.60
    let cardH = cardW * 0.62
    let cardR = cardW * 0.10

    let cards: [(dx: CGFloat, dy: CGFloat, scale: CGFloat, angle: CGFloat, alpha: CGFloat)] = [
        (-0.16, 0.13, 0.86, 9.5, 0.28),
        (-0.07, 0.05, 0.93, 5.0, 0.42),
        (0.04, -0.05, 1.00, 0.0, 0.95)
    ]

    for card in cards {
        ctx.saveGState()
        ctx.translateBy(x: body.midX + body.width * card.dx,
                        y: body.midY + body.height * card.dy)
        ctx.rotate(by: card.angle * .pi / 180)
        ctx.scaleBy(x: card.scale, y: card.scale)

        let r = CGRect(x: -cardW / 2, y: -cardH / 2, width: cardW, height: cardH)
        let path = rounded(r, cardR)

        ctx.setShadow(offset: CGSize(width: 0, height: -S * 0.010), blur: S * 0.030,
                      color: NSColor.black.withAlphaComponent(0.40).cgColor)
        ctx.addPath(path)
        ctx.setFillColor(NSColor.white.withAlphaComponent(card.alpha * 0.55).cgColor)
        ctx.fillPath()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)

        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        if let g = CGGradient(colorsSpace: cs,
                              colors: [NSColor.white.withAlphaComponent(card.alpha * 0.95).cgColor,
                                       NSColor.white.withAlphaComponent(card.alpha * 0.45).cgColor] as CFArray,
                              locations: [0, 1]) {
            ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: r.maxY),
                                   end: CGPoint(x: 0, y: r.minY), options: [])
        }

        if card.alpha > 0.9 {
            let bar = CGRect(x: r.minX, y: r.maxY - cardH * 0.19,
                             width: cardW, height: cardH * 0.19)
            ctx.setFillColor(NSColor(srgbRed: 0.20, green: 0.17, blue: 0.45, alpha: 0.30).cgColor)
            ctx.fill(bar)

            let dot = cardH * 0.055
            let colors = [NSColor(srgbRed: 1.00, green: 0.42, blue: 0.40, alpha: 0.95),
                          NSColor(srgbRed: 1.00, green: 0.78, blue: 0.30, alpha: 0.95),
                          NSColor(srgbRed: 0.38, green: 0.85, blue: 0.44, alpha: 0.95)]
            for (i, c) in colors.enumerated() {
                let x = r.minX + cardW * 0.075 + CGFloat(i) * dot * 2.5
                ctx.setFillColor(c.cgColor)
                ctx.fillEllipse(in: CGRect(x: x, y: bar.midY - dot / 2, width: dot, height: dot))
            }

            ctx.saveGState()
            ctx.addPath(path)
            ctx.clip()
            ctx.rotate(by: -28 * .pi / 180)
            if let g = CGGradient(colorsSpace: cs,
                                  colors: [NSColor.white.withAlphaComponent(0).cgColor,
                                           NSColor.white.withAlphaComponent(0.55).cgColor,
                                           NSColor.white.withAlphaComponent(0).cgColor] as CFArray,
                                  locations: [0, 0.5, 1]) {
                ctx.drawLinearGradient(g, start: CGPoint(x: -cardW * 0.30, y: 0),
                                       end: CGPoint(x: cardW * 0.22, y: 0), options: [])
            }
            ctx.restoreGState()
        }
        ctx.restoreGState()

        ctx.addPath(path)
        ctx.setStrokeColor(NSColor.white.withAlphaComponent(card.alpha * 0.85).cgColor)
        ctx.setLineWidth(max(1, S * 0.004))
        ctx.strokePath()
        ctx.restoreGState()
    }

    ctx.addPath(rounded(body.insetBy(dx: S * 0.004, dy: S * 0.004), radius))
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.22).cgColor)
    ctx.setLineWidth(max(1, S * 0.005))
    ctx.strokePath()

    ctx.restoreGState()
    return ctx.makeImage()
}

func write(_ image: CGImage, to path: String) {
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: image.width, height: image.height)
    guard let data = rep.representation(using: .png, properties: [:]) else { return }
    try? data.write(to: URL(fileURLWithPath: path))
}

let sizes: [(px: Int, name: String)] = [
    (16, "icon_16x16"), (32, "icon_16x16@2x"),
    (32, "icon_32x32"), (64, "icon_32x32@2x"),
    (128, "icon_128x128"), (256, "icon_128x128@2x"),
    (256, "icon_256x256"), (512, "icon_256x256@2x"),
    (512, "icon_512x512"), (1024, "icon_512x512@2x")
]

for s in sizes {
    guard let img = drawIcon(size: CGFloat(s.px)) else { continue }
    write(img, to: "\(outDir)/\(s.name).png")
}

print("ikon karolari yazildi: \(outDir)")