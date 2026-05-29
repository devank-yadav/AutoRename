import Foundation
import PDFKit
import AppKit

/// Extracts text from PDFs (PDFKit), Word .docx (unzip + XML), and plain/rtf text.
enum DocumentExtractor {
    private static let maxChars = 4000

    static func fill(_ ctx: inout FileContext) throws {
        let ext = ctx.url.pathExtension.lowercased()
        let text: String
        switch ext {
        case "pdf":            text = pdfText(ctx.url)
        case "docx":           text = docxText(ctx.url)
        case "rtf":            text = rtfText(ctx.url)
        default:               text = plainText(ctx.url)   // txt, md, and other text/*
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AutoRenameError.extractionEmpty }
        ctx.text = String(trimmed.prefix(maxChars))
    }

    private static func pdfText(_ url: URL) -> String {
        guard let doc = PDFDocument(url: url) else { return "" }
        var out = ""
        for i in 0..<min(doc.pageCount, 10) {
            if let page = doc.page(at: i), let s = page.string {
                out += s + "\n"
                if out.count > maxChars { break }
            }
        }
        return out
    }

    private static func docxText(_ url: URL) -> String {
        // .docx is a zip; the body lives in word/document.xml as <w:t> runs.
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        proc.arguments = ["-p", url.path, "word/document.xml"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        do {
            try proc.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            let xml = String(data: data, encoding: .utf8) ?? ""
            return stripWordXML(xml)
        } catch {
            return ""
        }
    }

    /// Pull readable text out of WordprocessingML: paragraphs to newlines, runs joined.
    private static func stripWordXML(_ xml: String) -> String {
        var s = xml.replacingOccurrences(of: "</w:p>", with: "\n")
        // Remove all remaining tags.
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        // Decode the few XML entities Word emits.
        let entities = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"", "&apos;": "'"]
        for (k, v) in entities { s = s.replacingOccurrences(of: k, with: v) }
        return s
    }

    private static func rtfText(_ url: URL) -> String {
        guard let attr = try? NSAttributedString(
            url: url,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil) else { return "" }
        return attr.string
    }

    private static func plainText(_ url: URL) -> String {
        (try? String(contentsOf: url, encoding: .utf8))
            ?? (try? String(contentsOf: url, encoding: .isoLatin1))
            ?? ""
    }
}
