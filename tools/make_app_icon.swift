import AppKit

// Renders the app icon master at 1024×1024: a rounded-rect (squircle-ish)
// gradient tile with the white "wand.and.stars" glyph, matching the menu bar.
// Output: build/AppIcon-1024.png

let S: CGFloat = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { fatalError("rep") }

let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx
ctx.imageInterpolation = .high

// Rounded tile with a small margin (macOS icons leave breathing room).
let margin: CGFloat = 80
let tile = NSRect(x: margin, y: margin, width: S - 2 * margin, height: S - 2 * margin)
let radius: CGFloat = tile.width * 0.235
let tilePath = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)
tilePath.addClip()

// Diagonal blue→indigo gradient.
let grad = NSGradient(starting: NSColor(calibratedRed: 0.36, green: 0.55, blue: 1.0, alpha: 1),
                      ending: NSColor(calibratedRed: 0.40, green: 0.27, blue: 0.92, alpha: 1))!
grad.draw(in: tile, angle: -55)

// Subtle top highlight for depth.
let gloss = NSGradient(colors: [NSColor(white: 1, alpha: 0.22), NSColor(white: 1, alpha: 0.0)])!
gloss.draw(in: NSRect(x: tile.minX, y: tile.midY, width: tile.width, height: tile.height / 2),
           angle: -90)

NSGraphicsContext.restoreGraphicsState()

// White glyph centered on the tile.
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx
let base = NSImage(systemSymbolName: "wand.and.stars", accessibilityDescription: nil)!
let cfg = NSImage.SymbolConfiguration(pointSize: 560, weight: .semibold)
    .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
let glyph = base.withSymbolConfiguration(cfg)!
let g = glyph.size
let rect = NSRect(x: (S - g.width) / 2, y: (S - g.height) / 2 - 10, width: g.width, height: g.height)
glyph.draw(in: rect)
NSGraphicsContext.restoreGraphicsState()

let out = URL(fileURLWithPath: "build/AppIcon-1024.png")
try! FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
try! rep.representation(using: .png, properties: [:])!.write(to: out)
print("wrote \(out.path)")
