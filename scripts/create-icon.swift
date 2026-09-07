#!/usr/bin/env swift
// Original CoreGraphics artwork. Regenerate with: swift scripts/create-icon.swift
// The application build copies the prebuilt .icns and does not run this script.
import AppKit
import Foundation

let project = URL(fileURLWithPath: #filePath).standardizedFileURL.deletingLastPathComponent().deletingLastPathComponent()
let assets = project.appendingPathComponent("assets", isDirectory: true)
let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("Atelier-icon-" + UUID().uuidString, isDirectory: true)
let iconset = scratch.appendingPathComponent("Atelier.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: scratch) }

func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

func drawIcon(pixels: Int) throws -> Data {
    let space = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                                  bytesPerRow: pixels * 4, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        throw NSError(domain: "AtelierIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create icon bitmap."])
    }
    context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)

    let tile = CGPath(roundedRect: CGRect(x: 94, y: 94, width: 836, height: 836), cornerWidth: 188, cornerHeight: 188, transform: nil)
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -10), blur: 23, color: rgba(0.015, 0.025, 0.03, 0.35))
    context.addPath(tile)
    context.setFillColor(rgba(0.08, 0.12, 0.14))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(tile)
    context.clip()
    let background = CGGradient(colorsSpace: space,
                                colors: [rgba(0.054, 0.088, 0.108), rgba(0.13, 0.18, 0.20)] as CFArray,
                                locations: [0, 1])!
    context.drawLinearGradient(background, start: CGPoint(x: 360, y: 110), end: CGPoint(x: 650, y: 930), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    context.restoreGState()

    let inset = CGPath(roundedRect: CGRect(x: 102, y: 102, width: 820, height: 820), cornerWidth: 181, cornerHeight: 181, transform: nil)
    context.addPath(inset)
    context.setStrokeColor(rgba(0.92, 0.88, 0.73, 0.13))
    context.setLineWidth(2)
    context.strokePath()

    // A single symmetric architectural mark: curved piers, an open arch and
    // three terraces create an Eiffel silhouette that also reads as an A.
    let mark = CGMutablePath()
    mark.move(to: CGPoint(x: 512, y: 826))
    mark.addCurve(to: CGPoint(x: 440, y: 435), control1: CGPoint(x: 500, y: 659), control2: CGPoint(x: 479, y: 539))
    mark.addCurve(to: CGPoint(x: 323, y: 223), control1: CGPoint(x: 410, y: 357), control2: CGPoint(x: 368, y: 274))
    mark.addLine(to: CGPoint(x: 415, y: 223))
    mark.addCurve(to: CGPoint(x: 483, y: 435), control1: CGPoint(x: 438, y: 309), control2: CGPoint(x: 468, y: 372))
    mark.addCurve(to: CGPoint(x: 512, y: 826), control1: CGPoint(x: 506, y: 544), control2: CGPoint(x: 517, y: 682))
    mark.closeSubpath()
    var mirror = CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 1024, ty: 0)
    var components: [CGPath] = [mark]
    if let reflected = mark.copy(using: &mirror) { components.append(reflected) }

    // Terraces remain broad and clean enough to survive a 16-pixel rendering.
    components.append(CGPath(roundedRect: CGRect(x: 391, y: 365, width: 242, height: 23), cornerWidth: 4, cornerHeight: 4, transform: nil))
    components.append(CGPath(roundedRect: CGRect(x: 454, y: 540, width: 116, height: 18), cornerWidth: 3, cornerHeight: 3, transform: nil))
    components.append(CGPath(roundedRect: CGRect(x: 489, y: 735, width: 46, height: 13), cornerWidth: 3, cornerHeight: 3, transform: nil))
    components.append(CGPath(roundedRect: CGRect(x: 506, y: 815, width: 12, height: 52), cornerWidth: 6, cornerHeight: 6, transform: nil))

    let arch = CGMutablePath()
    arch.move(to: CGPoint(x: 415, y: 247))
    arch.addCurve(to: CGPoint(x: 512, y: 353), control1: CGPoint(x: 439, y: 326), control2: CGPoint(x: 476, y: 353))
    arch.addCurve(to: CGPoint(x: 609, y: 247), control1: CGPoint(x: 548, y: 353), control2: CGPoint(x: 585, y: 326))
    components.append(arch.copy(strokingWithWidth: 14, lineCap: .round, lineJoin: .round, miterLimit: 2))

    let gold = CGGradient(colorsSpace: space,
                          colors: [rgba(0.68, 0.51, 0.29), rgba(0.89, 0.79, 0.57), rgba(0.98, 0.94, 0.81)] as CFArray,
                          locations: [0, 0.46, 1])!
    for component in components {
        context.saveGState()
        context.addPath(component)
        context.clip()
        context.drawLinearGradient(gold, start: CGPoint(x: 460, y: 220), end: CGPoint(x: 590, y: 870), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        context.restoreGState()
    }

    guard let image = context.makeImage(), let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        throw NSError(domain: "AtelierIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not encode icon PNG."])
    }
    return png
}

for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let suffix = scale == 2 ? "@2x" : ""
        let png = try drawIcon(pixels: pixels)
        try png.write(to: iconset.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
        if points == 256 && scale == 1 || points == 512 {
            try png.write(to: assets.appendingPathComponent("Atelier-\(pixels).png"))
        }
    }
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["--convert", "icns", iconset.path, "--output", assets.appendingPathComponent("Atelier.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { exit(iconutil.terminationStatus) }
print("Created assets/Atelier.icns and 256/512/1024-pixel review images.")
