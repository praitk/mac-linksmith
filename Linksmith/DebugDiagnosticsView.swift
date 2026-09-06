import SwiftUI
import LinksmithCore

struct DebugDiagnosticsView: View {
    @Bindable var diagnostics: DebugDiagnostics

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Linksmith Debug")
                        .font(.headline)
                    Text(diagnostics.buildDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .textSelection(.enabled)
                }

                Spacer()

                Button("Clear") {
                    diagnostics.clear()
                }
            }

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(diagnostics.entries) { entry in
                            DebugLogRow(entry: entry)
                                .id(entry.id)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
                .onChange(of: diagnostics.entries) { _, entries in
                    guard let last = entries.last else { return }
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
            .font(.system(.caption, design: .monospaced))
            .textSelection(.enabled)
        }
        .padding(16)
        .frame(width: 620, height: 360)
        .onAppear { diagnostics.start() }
        .onDisappear { diagnostics.stop() }
    }
}

private struct DebugLogRow: View {
    let entry: DebugLogEntry

    var body: some View {
        Text("\(Self.formatter.string(from: entry.date)) [\(entry.process)] \(entry.message)")
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()
}
