import Foundation
import AppKit

// Standalone CLI that exercises the real pipeline end-to-end on generated
// sample files: on-device extraction → naming → sanitize → actual rename.
// Naming uses the real Claude key if present in Keychain; otherwise a local
// fallback (first words of the extracted text) so the rename still runs.

let settings = SettingsStore.shared

func fallbackName(_ ctx: FileContext) -> String {
    let words = (ctx.tags + ctx.text.split(separator: " ").map(String.init))
        .filter { $0.count > 2 }
        .prefix(6)
    return words.isEmpty ? ctx.originalName : words.joined(separator: " ")
}

func makeSamples(in dir: URL) throws -> [URL] {
    let fm = FileManager.default
    try fm.createDirectory(at: dir, withIntermediateDirectories: true)

    var urls: [URL] = []

    let notes = dir.appendingPathComponent("Untitled 1.txt")
    try """
    Quarterly roadmap planning meeting for the mobile team.
    Action items: ship the login redesign, fix the crash on startup,
    and prepare the Q3 budget review before the end of the month.
    """.write(to: notes, atomically: true, encoding: .utf8)
    urls.append(notes)

    let recipe = dir.appendingPathComponent("doc2.md")
    try """
    # Classic Margherita Pizza Recipe
    A simple Neapolitan pizza with San Marzano tomatoes, fresh mozzarella,
    basil, and olive oil. Bake at 500F for 8 minutes.
    """.write(to: recipe, atomically: true, encoding: .utf8)
    urls.append(recipe)

    // Bonus: a PNG with rendered text to exercise Vision OCR (no TCC needed).
    if let png = renderTextPNG("INVOICE 2026 — Acme Corp — Total Due $4,250") {
        let img = dir.appendingPathComponent("scan_0001.png")
        try png.write(to: img)
        urls.append(img)
    }
    return urls
}

func renderTextPNG(_ text: String) -> Data? {
    let size = NSSize(width: 800, height: 200)
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx
    NSColor.white.setFill()
    NSRect(origin: .zero, size: size).fill()
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.boldSystemFont(ofSize: 36),
        .foregroundColor: NSColor.black,
    ]
    text.draw(at: NSPoint(x: 24, y: 80), withAttributes: attrs)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

// ---- run ----

let tmp = FileManager.default.temporaryDirectory
    .appendingPathComponent("AutoRenameTest-\(UUID().uuidString.prefix(8))")

do {
    let urls = try makeSamples(in: tmp)
    print("Sample dir: \(tmp.path)\n")
    let usingAPI = (settings.apiKey?.isEmpty == false)
    print("Naming via: \(usingAPI ? "OpenAI API (real key found)" : "local fallback (no API key set)")\n")

    var taken = Set<String>()
    for url in urls {
        let kind = Extractor.kind(for: url)
        do {
            let ctx = try await Extractor.extract(url)
            let snippet = ctx.text.prefix(60).replacingOccurrences(of: "\n", with: " ")
            print("• \(url.lastPathComponent)  [\(kind.rawValue)]")
            print("    extracted: \"\(snippet)\(ctx.text.count > 60 ? "…" : "")\"")
            if !ctx.tags.isEmpty { print("    tags: \(ctx.tags.joined(separator: ", "))") }

            var raw: String
            if usingAPI {
                do { raw = try await NamingService.suggest(for: ctx, settings: settings) }
                catch { print("    (API failed: \(error.localizedDescription) — using fallback)")
                        raw = fallbackName(ctx) }
            } else {
                raw = fallbackName(ctx)
            }
            let base = FilenameSanitizer.finalize(raw, context: ctx, settings: settings)
            let dest = FilenameSanitizer.uniqueURL(for: base, ext: ctx.ext, in: tmp, taken: &taken)
            try FileManager.default.moveItem(at: url, to: dest)
            print("    RENAMED → \(dest.lastPathComponent)\n")
        } catch {
            print("    SKIPPED: \(error.localizedDescription)\n")
        }
    }

    print("Final directory contents:")
    let listing = try FileManager.default.contentsOfDirectory(atPath: tmp.path).sorted()
    for f in listing { print("  \(f)") }
} catch {
    print("Test setup failed: \(error)")
    exit(1)
}
