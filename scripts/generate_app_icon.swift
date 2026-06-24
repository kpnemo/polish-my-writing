#!/usr/bin/env swift
import AppKit

// Generates the macOS AppIcon set into App/Assets.xcassets/AppIcon.appiconset.
// Design: rounded-square (squircle-ish) with an indigo→violet gradient and a
// white SF Symbol glyph implying "editing / polishing writing".

let glyphCandidates = ["pencil.and.scribble", "pencil.and.outline", "highlighter", "pencil"]

func glyphImage(pointSize: CGFloat) -> NSImage {
    let cfg = NSImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    for name in glyphCandidates {
        if let base = NSImage(systemSymbolName: name, accessibilityDescription: nil),
           let img = base.withSymbolConfiguration(cfg) {
            return img
        }
    }
    fatalError("No glyph symbol available")
}

func renderIcon(size: Int) -> Data {
    let dim = CGFloat(size)
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    )!
    rep.size = NSSize(width: dim, height: dim)

    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    ctx.imageInterpolation = .high

    // Rounded-square plate with margin (Apple-ish proportions).
    let margin = dim * 0.085
    let plate = NSRect(x: margin, y: margin, width: dim - 2 * margin, height: dim - 2 * margin)
    let radius = plate.width * 0.2237
    let path = NSBezierPath(roundedRect: plate, xRadius: radius, yRadius: radius)

    // Diagonal indigo → violet gradient.
    let top = NSColor(srgbRed: 0.36, green: 0.45, blue: 0.99, alpha: 1.0)    // #5C73FD
    let bottom = NSColor(srgbRed: 0.55, green: 0.27, blue: 0.90, alpha: 1.0) // #8B45E6
    let gradient = NSGradient(colors: [top, bottom])!
    gradient.draw(in: path, angle: -65)

    // Subtle top highlight for depth.
    let highlight = NSGradient(colors: [
        NSColor(white: 1.0, alpha: 0.16), NSColor(white: 1.0, alpha: 0.0),
    ])!
    highlight.draw(in: path, angle: -90)

    // Centered white glyph.
    let glyph = glyphImage(pointSize: dim * 0.50)
    let gs = glyph.size
    let gx = (dim - gs.width) / 2
    let gy = (dim - gs.height) / 2
    glyph.draw(in: NSRect(x: gx, y: gy, width: gs.width, height: gs.height),
               from: .zero, operation: .sourceOver, fraction: 1.0)

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// macOS app icon sizes (pt@scale -> px).
let entries: [(idiom: String, sizePt: Int, scale: Int)] = [
    ("mac", 16, 1), ("mac", 16, 2),
    ("mac", 32, 1), ("mac", 32, 2),
    ("mac", 128, 1), ("mac", 128, 2),
    ("mac", 256, 1), ("mac", 256, 2),
    ("mac", 512, 1), ("mac", 512, 2),
]

let outDir = "App/Assets.xcassets/AppIcon.appiconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

var images: [[String: String]] = []
var written = Set<Int>()
for e in entries {
    let px = e.sizePt * e.scale
    let file = "icon_\(px).png"
    if !written.contains(px) {
        try! renderIcon(size: px).write(to: URL(fileURLWithPath: "\(outDir)/\(file)"))
        written.insert(px)
    }
    images.append([
        "idiom": e.idiom,
        "size": "\(e.sizePt)x\(e.sizePt)",
        "scale": "\(e.scale)x",
        "filename": file,
    ])
}

let contents: [String: Any] = [
    "images": images,
    "info": ["version": 1, "author": "xcode"],
]
let data = try! JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try! data.write(to: URL(fileURLWithPath: "\(outDir)/Contents.json"))

print("Wrote \(written.count) PNGs + Contents.json to \(outDir)")
