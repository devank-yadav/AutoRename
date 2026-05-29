import SwiftUI
import UniformTypeIdentifiers

struct DropView: View {
    let onDropURLs: ([URL]) -> Void
    @State private var hovering = false

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 40))
                .foregroundColor(hovering ? .accentColor : .secondary)
            Text("Drop files here to auto-rename")
                .font(.headline)
            Text("Images, PDFs, docs, audio, and video")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(width: 360, height: 220)
        .background(hovering ? Color.accentColor.opacity(0.12) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                .foregroundColor(hovering ? .accentColor : .secondary.opacity(0.4))
                .padding(8)
        )
        .onDrop(of: [.fileURL], isTargeted: $hovering) { providers in
            loadURLs(from: providers)
            return true
        }
    }

    private func loadURLs(from providers: [NSItemProvider]) {
        let group = DispatchGroup()
        var urls: [URL] = []
        let lock = NSLock()
        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url {
                    lock.lock(); urls.append(url); lock.unlock()
                }
                group.leave()
            }
        }
        group.notify(queue: .main) {
            if !urls.isEmpty { onDropURLs(urls) }
        }
    }
}
