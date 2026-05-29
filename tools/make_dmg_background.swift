import AppKit

// Renders the DMG window background: title, hint text, and a drag-to-install
// arrow pointing from the app icon toward the Applications shortcut.
// Output: Resources/dmg-background.png (660 x 400, matching the DMG window).

let W = 660, H = 400
let size = NSSize(width: W, height: H)

guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: W * 2, pixelsHigh: H * 2,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else {
    fatalError("rep")
}
rep.size = size  // 2x pixels, 1x points → crisp on Retina

let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx
ctx.imageInterpolation = .high

// Vertical gradient background.
let bg = NSGradient(starting: NSColor(calibratedRed: 0.96, green: 0.97, blue: 1.0, alpha: 1),
                    ending: NSColor(calibratedRed: 0.89, green: 0.92, blue: 0.98, alpha: 1))!
bg.draw(in: NSRect(x: 0, y: 0, width: W, height: H), angle: -90)

func drawCentered(_ s: String, font: NSFont, color: NSColor, centerX: CGFloat, topY: CGFloat) {
    let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
    let str = NSAttributedString(string: s, attributes: attrs)
    let sz = str.size()
    str.draw(at: NSPoint(x: centerX - sz.width / 2, y: CGFloat(H) - topY - sz.height))
}

// Title + subtitle near the top.
drawCentered("AutoRename", font: .systemFont(ofSize: 30, weight: .bold),
             color: NSColor(white: 0.13, alpha: 1), centerX: CGFloat(W) / 2, topY: 36)
drawCentered("Drag the app onto the Applications folder to install",
             font: .systemFont(ofSize: 14, weight: .regular),
             color: NSColor(white: 0.4, alpha: 1), centerX: CGFloat(W) / 2, topY: 76)

// Drag arrow between the two icon slots (icons sit at AppKit y ≈ 210).
let arrowY: CGFloat = 220
let path = NSBezierPath()
path.lineWidth = 6
path.lineCapStyle = .round
path.lineJoinStyle = .round
path.move(to: NSPoint(x: 270, y: arrowY))
path.line(to: NSPoint(x: 388, y: arrowY))
NSColor(calibratedRed: 0.30, green: 0.48, blue: 0.95, alpha: 0.9).setStroke()
path.stroke()

let head = NSBezierPath()
head.move(to: NSPoint(x: 410, y: arrowY))
head.line(to: NSPoint(x: 384, y: arrowY + 14))
head.line(to: NSPoint(x: 384, y: arrowY - 14))
head.close()
NSColor(calibratedRed: 0.30, green: 0.48, blue: 0.95, alpha: 0.9).setFill()
head.fill()

NSGraphicsContext.restoreGraphicsState()

let outURL = URL(fileURLWithPath: "Resources/dmg-background.png")
guard let data = rep.representation(using: .png, properties: [:]) else { fatalError("png") }
try! data.write(to: outURL)
print("wrote \(outURL.path) (\(W)x\(H) @2x)")
