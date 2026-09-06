import AppKit
import SwiftUI

@MainActor
final class LinksmithAppDelegate: NSObject, NSApplicationDelegate {
    #if DEBUG
    private let diagnostics = DebugDiagnostics()
    private var debugWindow: NSWindow?
    #endif
    private lazy var workflowRunner = makeWorkflowRunner()
    private var pendingActionTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        diagnostics.start()
        diagnostics.log("Application did finish launching.")
        #endif
        startPendingActionWatcher()
        performPendingAction()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        #if DEBUG
        diagnostics.log("Application became active.")
        #endif
        performPendingAction()
    }

    func applicationWillTerminate(_ notification: Notification) {
        stopPendingActionWatcher()
        #if DEBUG
        diagnostics.stop()
        #endif
    }

    func showDebugWindow() {
        #if DEBUG
        if let debugWindow {
            debugWindow.orderFrontRegardless()
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 360),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.identifier = NSUserInterfaceItemIdentifier("LinksmithDebugDiagnostics")
        window.title = "Linksmith Debug"
        window.level = .floating
        window.contentView = NSHostingView(rootView: DebugDiagnosticsView(diagnostics: diagnostics))
        window.center()
        window.orderFrontRegardless()
        debugWindow = window
        #endif
    }

    private func makeWorkflowRunner() -> LinkWorkflowRunner {
        #if DEBUG
        LinkWorkflowRunner(diagnostics: diagnostics)
        #else
        LinkWorkflowRunner()
        #endif
    }

    private func startPendingActionWatcher() {
        guard pendingActionTimer == nil else { return }
        pendingActionTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.performPendingAction()
            }
        }
    }

    private func stopPendingActionWatcher() {
        pendingActionTimer?.invalidate()
        pendingActionTimer = nil
    }

    private func performPendingAction() {
        #if DEBUG
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.workflowRunner.performPendingActionIfAvailable()
        }
        #else
        workflowRunner.performPendingActionIfAvailable()
        #endif
    }
}
