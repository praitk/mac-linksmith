//
//  ContentView.swift
//  Linksmith
//
//  Created by Niccolò Quattropani on 16.08.2026.
//

import SwiftUI
import LinksmithCore

struct ContentView: View {
    @State private var kind = SharedSettings().symlinkKind

    var body: some View {
        Form {
            Section("Create Symlink") {
                Picker("Default link type", selection: $kind) {
                    Text("Relative").tag(SymlinkKind.relative)
                    Text("Absolute").tag(SymlinkKind.absolute)
                }
                .pickerStyle(.segmented)
                Text(kind == .relative
                     ? "Relative links keep working when the source and link are moved together."
                     : "Absolute links always point to the source's full path.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 210)
        .onChange(of: kind) { _, newValue in SharedSettings().symlinkKind = newValue }
    }
}

#Preview {
    ContentView()
}
