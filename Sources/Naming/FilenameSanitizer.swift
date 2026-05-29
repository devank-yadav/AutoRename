import Foundation

/// Turns a raw AI suggestion into a safe filename base, applying the user's
/// template, case style, length cap, and optional date prefix.
enum FilenameSanitizer {
    static func finalize(_ raw: String, context: FileContext, settings: SettingsStore) -> String {
        var name = raw
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Strip any extension the model may have added, and quotes/backticks.
        name = name.replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "`", with: "")
        if let dot = name.lastIndex(of: "."), name.distance(from: dot, to: name.endIndex) <= 5 {
            name = String(name[..<dot])
        }

        let slug = applyCase(words(from: name), style: settings.caseStyle)
        let base = slug.isEmpty ? context.originalName : slug

        var result = settings.template.replacingOccurrences(of: "{slug}", with: base)
        let dateStr = dateString(context.createdAt)
        result = result.replacingOccurrences(of: "{date}", with: dateStr)
        if settings.prependDate && !settings.template.contains("{date}") {
            result = "\(dateStr)-\(result)"
        }

        result = removeIllegal(result)
        if result.count > settings.maxLength {
            result = String(result.prefix(settings.maxLength))
                .trimmingCharacters(in: CharacterSet(charactersIn: "-_ "))
        }
        return result.isEmpty ? context.originalName : result
    }

    /// Split into words on whitespace and separators.
    private static func words(from s: String) -> [String] {
        s.components(separatedBy: CharacterSet(charactersIn: " -_./\\"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private static func applyCase(_ words: [String], style: CaseStyle) -> String {
        switch style {
        case .kebab: return words.map { $0.lowercased() }.joined(separator: "-")
        case .snake: return words.map { $0.lowercased() }.joined(separator: "_")
        case .lower: return words.map { $0.lowercased() }.joined(separator: " ")
        case .title: return words.map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
                                 .joined(separator: " ")
        }
    }

    private static func dateString(_ date: Date?) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date ?? Date())
    }

    /// Remove characters illegal on macOS/most filesystems.
    private static func removeIllegal(_ s: String) -> String {
        let illegal = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        return s.components(separatedBy: illegal).joined()
            .trimmingCharacters(in: .whitespaces)
    }

    /// Resolve collisions within a directory by appending -2, -3, …
    static func uniqueURL(for base: String, ext: String, in directory: URL,
                          taken: inout Set<String>) -> URL {
        func candidate(_ name: String) -> URL {
            ext.isEmpty ? directory.appendingPathComponent(name)
                        : directory.appendingPathComponent(name).appendingPathExtension(ext)
        }
        var name = base
        var n = 2
        while taken.contains(name.lowercased())
                || FileManager.default.fileExists(atPath: candidate(name).path) {
            name = "\(base)-\(n)"
            n += 1
        }
        taken.insert(name.lowercased())
        return candidate(name)
    }
}
