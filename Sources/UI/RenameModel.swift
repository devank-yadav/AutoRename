import SwiftUI

struct RenameRow: Identifiable {
    let id = UUID()
    let url: URL
    let originalName: String
    let ext: String
    var proposedBase: String
    var statusText: String
    var enabled: Bool
    var ready: Bool

    var proposedFullName: String {
        ext.isEmpty ? proposedBase : "\(proposedBase).\(ext)"
    }

    init(url: URL) {
        self.url = url
        self.originalName = url.lastPathComponent
        self.ext = url.pathExtension
        self.proposedBase = url.deletingPathExtension().lastPathComponent
        self.statusText = "Queued"
        self.enabled = true
        self.ready = false
    }
}

@MainActor
final class RenameModel: ObservableObject {
    @Published var rows: [RenameRow]
    @Published var isProcessing = false
    @Published var summary = ""

    private let settings = SettingsStore.shared

    init(urls: [URL]) {
        rows = urls.map(RenameRow.init)
    }

    func process() async {
        isProcessing = true
        summary = ""
        await withTaskGroup(of: Void.self) { group in
            for row in rows {
                let id = row.id
                let url = row.url
                group.addTask { [weak self] in
                    await self?.processOne(id: id, url: url)
                }
            }
        }
        isProcessing = false
        let readyCount = rows.filter { $0.ready }.count
        summary = "\(readyCount) of \(rows.count) ready to rename."
    }

    private func processOne(id: UUID, url: URL) async {
        update(id) { $0.statusText = "Reading…" }
        do {
            let ctx = try await Extractor.extract(url)
            update(id) { $0.statusText = "Naming…" }
            let raw = try await NamingService.suggest(for: ctx, settings: settings)
            let base = FilenameSanitizer.finalize(raw, context: ctx, settings: settings)
            update(id) {
                $0.proposedBase = base
                $0.ready = true
                $0.statusText = "Ready"
            }
        } catch {
            let msg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            update(id) {
                $0.enabled = false
                $0.statusText = "Skipped: \(msg)"
            }
        }
    }

    private func update(_ id: UUID, _ mutate: (inout RenameRow) -> Void) {
        guard let i = rows.firstIndex(where: { $0.id == id }) else { return }
        mutate(&rows[i])
    }

    /// Apply renames for enabled rows. Returns a result summary.
    func apply() {
        var taken = Set<String>()
        var renamed = 0
        var failed = 0
        for i in rows.indices {
            guard rows[i].enabled, rows[i].ready else { continue }
            let row = rows[i]
            let dir = row.url.deletingLastPathComponent()
            let dest = FilenameSanitizer.uniqueURL(for: row.proposedBase, ext: row.ext,
                                                   in: dir, taken: &taken)
            if dest.lastPathComponent == row.originalName {
                rows[i].statusText = "Unchanged"
                continue
            }
            do {
                try FileManager.default.moveItem(at: row.url, to: dest)
                rows[i].statusText = "Renamed → \(dest.lastPathComponent)"
                rows[i].ready = false
                renamed += 1
            } catch {
                rows[i].statusText = "Failed: \(error.localizedDescription)"
                failed += 1
            }
        }
        summary = "Renamed \(renamed)" + (failed > 0 ? ", \(failed) failed." : ".")
    }
}
