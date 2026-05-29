import Foundation
import Speech

/// On-device speech-to-text via the Speech framework.
enum AudioExtractor {
    private static let maxChars = 2000

    static func fill(_ ctx: inout FileContext) async throws {
        guard await requestAuth() else {
            throw AutoRenameError.extractionEmpty
        }
        let transcript = try await transcribe(ctx.url)
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AutoRenameError.extractionEmpty }
        ctx.text = String(trimmed.prefix(maxChars))
    }

    static func requestAuth() async -> Bool {
        await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { status in
                cont.resume(returning: status == .authorized)
            }
        }
    }

    static func transcribe(_ url: URL) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            throw AutoRenameError.extractionEmpty
        }
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true

        return try await withCheckedThrowingContinuation { cont in
            var finished = false
            var task: SFSpeechRecognitionTask?
            task = recognizer.recognitionTask(with: request) { result, error in
                if finished { return }
                if let result {
                    let text = result.bestTranscription.formattedString
                    // Stop early once we have enough text for a good name.
                    if result.isFinal || text.count >= maxChars {
                        finished = true
                        task?.cancel()
                        cont.resume(returning: text)
                    }
                } else if let error {
                    finished = true
                    cont.resume(throwing: AutoRenameError.apiError(error.localizedDescription))
                }
            }
        }
    }
}
