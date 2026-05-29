import Foundation
import UniformTypeIdentifiers

/// Routes a file to the right on-device extractor based on its uniform type.
enum Extractor {
    static func kind(for url: URL) -> FileKind {
        guard let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType else {
            return kindByExtension(url)
        }
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
        if type.conforms(to: .audio) { return .audio }
        if type.conforms(to: .pdf) || type.conforms(to: .text)
            || type.conforms(to: .plainText) || type.conforms(to: .rtf)
            || isWord(url) { return .document }
        return kindByExtension(url)
    }

    private static func isWord(_ url: URL) -> Bool {
        url.pathExtension.lowercased() == "docx"
    }

    private static func kindByExtension(_ url: URL) -> FileKind {
        switch url.pathExtension.lowercased() {
        case "png", "jpg", "jpeg", "heic", "gif", "tiff", "bmp", "webp": return .image
        case "pdf", "txt", "md", "rtf", "docx": return .document
        case "mp3", "m4a", "wav", "aac", "aiff", "flac": return .audio
        case "mp4", "mov", "m4v", "avi", "mkv": return .video
        default: return .unknown
        }
    }

    /// Extracts on-device context. Throws AutoRenameError for unsupported types.
    static func extract(_ url: URL) async throws -> FileContext {
        let created = (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate)
        let k = kind(for: url)
        var ctx = FileContext(url: url, kind: k, text: "", tags: [], createdAt: created)

        switch k {
        case .image:    try await ImageExtractor.fill(&ctx)
        case .document: try DocumentExtractor.fill(&ctx)
        case .audio:    try await AudioExtractor.fill(&ctx)
        case .video:    try await VideoExtractor.fill(&ctx)
        case .unknown:  throw AutoRenameError.unsupportedType(url.pathExtension)
        }
        return ctx
    }
}
