//
//  ActionRequestHandler.swift
//  LinksmithAction
//
//  Created by Niccolò Quattropani on 16.08.2026.
//

import AppKit
import Foundation
import LinksmithCore
import OSLog

@objc(ActionRequestHandler)
final class ActionRequestHandler: NSObject, NSExtensionRequestHandling {
    private static let logger = Logger(subsystem: "com.praitk.Linksmith", category: "LinksmithAction")
    private let pendingActions = PendingLinkActionStore()
    private let debugLog = DebugLogStore()

    func beginRequest(with context: NSExtensionContext) {
        log("Non-UI extension handler started.")
        log("Extension build: \(buildDescription)")
        FinderSelectionLoader.load(from: context) { [weak self, context] result in
            DispatchQueue.main.async {
                guard let self else {
                    context.cancelRequest(withError: LinksmithActionError.extensionContextUnavailable)
                    return
                }
                switch result {
                case .failure(let error):
                    self.cancel(context, with: error)
                case .success(let selection):
                    self.handOff(selection: selection, context: context)
                }
            }
        }
    }

    @MainActor
    private func handOff(selection: [URL], context: NSExtensionContext) {
        do {
            try pendingActions.saveSelection(selection)
            log("Saved pending handoff with \(selection.count) item(s).")
            openContainingApp()
            finishHandoffWithoutEditingFinderItems(context)
        } catch {
            cancel(context, with: error)
        }
    }

    private func openContainingApp() {
        let appURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        log("Opening containing app at: \(appURL.path)")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        configuration.allowsRunningApplicationSubstitution = false
        let debugLog = debugLog
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { app, error in
            if let error {
                Self.logger.error("Failed opening containing app: \(error.localizedDescription)")
                debugLog.append("Failed opening containing app: \(error.localizedDescription)", process: "Extension")
            } else {
                Self.logger.info("Opened containing app: \(app?.bundleIdentifier ?? "unknown")")
                debugLog.append("Opened containing app: \(app?.bundleIdentifier ?? "unknown")", process: "Extension")
            }
        }
    }

    private func finishHandoffWithoutEditingFinderItems(_ context: NSExtensionContext) {
        let error = NSError(domain: NSCocoaErrorDomain, code: NSUserCancelledError)
        Self.logger.info("Cancelling Finder request after successful handoff so Finder preserves original items.")
        log("Cancelling Finder request after handoff; Linksmith app owns the workflow now.")
        context.cancelRequest(withError: error)
    }

    private func cancel(_ context: NSExtensionContext, with error: Error) {
        Self.logger.error("Cancelling Linksmith action: \(error.localizedDescription)")
        log("Cancelling Finder extension request: \(error.localizedDescription)")
        context.cancelRequest(withError: error)
    }

    private func log(_ message: String) {
        debugLog.append(message, process: "Extension")
    }

    private var buildDescription: String {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        let timestamp = executableTimestamp.map(Self.timestampFormatter.string(from:)) ?? "unknown"
        return "Version \(version) (\(build)) - built \(timestamp)"
    }

    private var executableTimestamp: Date? {
        guard let executableURL = Bundle.main.executableURL,
              let values = try? executableURL.resourceValues(forKeys: [.contentModificationDateKey]) else {
            return nil
        }
        return values.contentModificationDate
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}
