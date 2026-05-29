import Foundation

/// Context extracted on-device from a single file, used to build the naming prompt.
struct FileContext {
    let url: URL
    let kind: FileKind
    /// Free-form text pulled from the file: OCR, transcript, document body, etc.
    var text: String
    /// Short descriptive tags (e.g. Vision scene labels).
    var tags: [String]
    /// File creation date, if known.
    var createdAt: Date?

    var originalName: String { url.deletingPathExtension().lastPathComponent }
    var ext: String { url.pathExtension }
}

enum FileKind: String {
    case image, document, audio, video, unknown
}

/// A single proposed rename, shown in the preview and applied on confirm.
final class RenameItem: Identifiable {
    let id = UUID()
    let url: URL
    var originalName: String
    /// Proposed base name (no extension). Editable in the preview.
    var proposedName: String
    var status: Status

    enum Status: Equatable {
        case pending
        case extracting
        case naming
        case ready
        case applied
        case skipped(String)
        case failed(String)
    }

    init(url: URL) {
        self.url = url
        self.originalName = url.lastPathComponent
        self.proposedName = url.deletingPathExtension().lastPathComponent
        self.status = .pending
    }

    var ext: String { url.pathExtension }
}

enum AutoRenameError: LocalizedError {
    case noAPIKey
    case unsupportedType(String)
    case extractionEmpty
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "No OpenAI API key set. Open Settings to add one."
        case .unsupportedType(let t): return "Unsupported file type: \(t)"
        case .extractionEmpty: return "Could not read any content from the file."
        case .apiError(let m): return "Naming request failed: \(m)"
        }
    }
}
