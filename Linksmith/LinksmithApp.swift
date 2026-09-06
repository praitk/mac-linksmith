//
//  LinksmithApp.swift
//  Linksmith
//
//  Created by Niccolò Quattropani on 16.08.2026.
//

import SwiftUI

@main
struct LinksmithApp: App {
    @NSApplicationDelegateAdaptor(LinksmithAppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Linksmith", systemImage: "link") {
            ContentView {
                appDelegate.showDebugWindow()
            }
        }
        .menuBarExtraStyle(.window)
    }
}
