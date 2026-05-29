import Foundation
import AVFoundation
import Vision
import CoreMedia

/// Samples keyframes (Vision) and the audio track (Speech) from a video.
enum VideoExtractor {
    static func fill(_ ctx: inout FileContext) async throws {
        let asset = AVURLAsset(url: ctx.url)

        var tags: [String] = []
        var ocr = ""
        if let frames = try? await sampleFrames(asset, count: 4) {
            for cg in frames {
                tags.append(contentsOf: classify(cg))
                let t = recognizeText(cg)
                if !t.isEmpty { ocr += t + " " }
            }
        }
        tags = Array(Set(tags)).prefix(8).map { $0 }

        var transcript = ""
        if let audioURL = try? await exportAudio(asset) {
            transcript = (try? await AudioExtractor.transcribe(audioURL)) ?? ""
            try? FileManager.default.removeItem(at: audioURL)
        }

        ctx.tags = tags
        ctx.text = (transcript + " " + ocr).trimmingCharacters(in: .whitespacesAndNewlines)
        if ctx.text.isEmpty && tags.isEmpty {
            throw AutoRenameError.extractionEmpty
        }
        ctx.text = String(ctx.text.prefix(2500))
    }

    private static func sampleFrames(_ asset: AVURLAsset, count: Int) async throws -> [CGImage] {
        let duration = try await asset.load(.duration)
        let total = CMTimeGetSeconds(duration)
        guard total > 0 else { return [] }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .positiveInfinity
        generator.requestedTimeToleranceAfter = .positiveInfinity

        var images: [CGImage] = []
        for i in 0..<count {
            let frac = (Double(i) + 0.5) / Double(count)
            let time = CMTime(seconds: total * frac, preferredTimescale: 600)
            if let cg = try? generator.copyCGImage(at: time, actualTime: nil) {
                images.append(cg)
            }
        }
        return images
    }

    private static func exportAudio(_ asset: AVURLAsset) async throws -> URL? {
        guard let session = AVAssetExportSession(asset: asset,
                                                 presetName: AVAssetExportPresetAppleM4A) else {
            return nil
        }
        let out = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        session.outputURL = out
        session.outputFileType = .m4a

        return try await withCheckedThrowingContinuation { cont in
            session.exportAsynchronously {
                switch session.status {
                case .completed: cont.resume(returning: out)
                default:         cont.resume(returning: nil)
                }
            }
        }
    }

    private static func classify(_ cg: CGImage) -> [String] {
        let request = VNClassifyImageRequest()
        try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([request])
        return (request.results ?? [])
            .filter { $0.confidence > 0.25 }
            .sorted { $0.confidence > $1.confidence }
            .prefix(3)
            .map { $0.identifier }
    }

    private static func recognizeText(_ cg: CGImage) -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        try? VNImageRequestHandler(cgImage: cg, options: [:]).perform([request])
        return (request.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: " ")
    }
}
