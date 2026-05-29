import Foundation

/// Sends the on-device-extracted context (text only, never the raw file) to
/// the OpenAI API and gets back a descriptive base filename.
enum NamingService {
    private static let model = "gpt-4o-mini"
    private static let endpoint = URL(string: "https://api.openai.com/v1/chat/completions")!

    static func suggest(for ctx: FileContext, settings: SettingsStore) async throws -> String {
        guard let key = settings.apiKey, !key.isEmpty else {
            throw AutoRenameError.noAPIKey
        }

        let prompt = buildPrompt(ctx, settings: settings)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 64,
            "temperature": 0.4,
            "messages": [["role": "user", "content": prompt]],
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AutoRenameError.apiError("No response")
        }
        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw AutoRenameError.apiError(msg)
        }
        return try parseText(data)
    }

    private static func buildPrompt(_ ctx: FileContext, settings: SettingsStore) -> String {
        var lines: [String] = []
        lines.append("You name files. Suggest ONE concise, descriptive filename for the file below.")
        lines.append("Return ONLY the name as plain words — no extension, no quotes, no explanation.")
        lines.append("Use \(settings.language). Keep it under \(settings.maxLength) characters.")
        lines.append("")
        lines.append("File type: \(ctx.kind.rawValue)")
        lines.append("Original name: \(ctx.originalName)")
        if !ctx.tags.isEmpty {
            lines.append("Detected subjects: \(ctx.tags.joined(separator: ", "))")
        }
        if !ctx.text.isEmpty {
            lines.append("Extracted content:")
            lines.append(ctx.text)
        }
        return lines.joined(separator: "\n")
    }

    private static func parseText(_ data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AutoRenameError.apiError("Malformed response")
        }
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw AutoRenameError.apiError("Empty response") }
        return text
    }
}
