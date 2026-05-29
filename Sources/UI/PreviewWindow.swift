import SwiftUI
import AppKit

struct PreviewView: View {
    @StateObject private var model: RenameModel
    let onClose: () -> Void

    init(urls: [URL], onClose: @escaping () -> Void) {
        _model = StateObject(wrappedValue: RenameModel(urls: urls))
        self.onClose = onClose
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Review proposed names")
                .font(.headline)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach($model.rows) { $row in
                        RenameRowView(row: $row)
                        Divider()
                    }
                }
            }
            .frame(minHeight: 240)

            HStack {
                if model.isProcessing { ProgressView().scaleEffect(0.6) }
                Text(model.summary).font(.caption).foregroundColor(.secondary)
                Spacer()
                Button("Cancel") { onClose() }
                Button("Apply Renames") {
                    model.apply()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.isProcessing || !model.rows.contains { $0.enabled && $0.ready })
            }
        }
        .padding(16)
        .frame(width: 640, height: 420)
        .task { await model.process() }
    }
}

private struct RenameRowView: View {
    @Binding var row: RenameRow

    var body: some View {
        HStack(spacing: 8) {
            Toggle("", isOn: $row.enabled)
                .labelsHidden()
                .disabled(!row.ready)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.originalName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    TextField("name", text: $row.proposedBase)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!row.ready)
                    if !row.ext.isEmpty {
                        Text(".\(row.ext)").font(.caption).foregroundColor(.secondary)
                    }
                }
                Text(row.statusText)
                    .font(.caption2)
                    .foregroundColor(row.ready ? .green : .secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }
}
