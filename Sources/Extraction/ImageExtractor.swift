import Foundation
import Vision
import AppKit

/// On-device OCR + scene classification via the Vision framework.
enum ImageExtractor {
    static func fill(_ ctx: inout FileContext) async throws {
        guard let image = NSImage(contentsOf: ctx.url),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw AutoRenameError.extractionEmpty
        }

        let text = recognizeText(cg)
        let tags = classify(cg)

        ctx.text = text
        ctx.tags = tags
        if text.isEmpty && tags.isEmpty {
            throw AutoRenameError.extractionEmpty
        }
    }

    private static func recognizeText(_ cg: CGImage) -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        try? handler.perform([request])
        let lines = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        // Cap OCR payload so the naming prompt stays small.
        return lines.joined(separator: " ").prefix(1500).description
    }

    private static func classify(_ cg: CGImage) -> [String] {
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        try? handler.perform([request])
        let results = (request.results ?? [])
            .filter { $0.confidence > 0.2 }
            .sorted { $0.confidence > $1.confidence }
            .prefix(5)
            .map { $0.identifier }
        return Array(results)
    }
}
