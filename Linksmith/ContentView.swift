import SwiftUI
import LinksmithCore

struct ContentView: View {
    let showDebugLog: () -> Void
    @State private var kind = SharedSettings().symlinkKind

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Linksmith")
                .font(.headline)

            Picker("Default Link Type", selection: $kind) {
                Text("Relative").tag(SymlinkKind.relative)
                Text("Absolute").tag(SymlinkKind.absolute)
            }
            .pickerStyle(.inline)

            Divider()

            #if DEBUG
            Button("Show Debug Log", action: showDebugLog)
            #endif

            Button("Quit Linksmith") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(14)
        .frame(width: 230)
        .onChange(of: kind) { _, newValue in
            SharedSettings().symlinkKind = newValue
        }
    }
}

#Preview {
    ContentView(showDebugLog: {})
}
