//
//  ActionRequestHandler.swift
//  LinksmithAction
//
//  Created by Niccolò Quattropani on 16.08.2026.
//

import AppKit
import Foundation
import LinksmithCore

@objc(ActionRequestHandler)
final class ActionRequestHandler: NSObject, NSExtensionRequestHandling {
    private let settings = SharedSettings()
    private let recents = RecentDestinationStore()
    private let service = SymlinkService()

    func beginRequest(with context: NSExtensionContext) {
        FinderSelectionLoader.load(from: context) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .failure(let error): context.cancelRequest(withError: error)
                case .success(let sources): self.createLinks(for: sources, context: context)
                }
            }
        }
    }

    @MainActor
    private func createLinks(for sources: [URL], context: NSExtensionContext) {
        guard let destination = DestinationChooser(recentURLs: recents.resolvedURLs()).choose() else {
            context.cancelRequest(withError: CocoaError(.userCancelled))
            return
        }
        let scopedURLs = sources + [destination]
        let access = scopedURLs.map { $0.startAccessingSecurityScopedResource() }
        defer {
            for (url, didStart) in zip(scopedURLs, access) where didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        do {
            _ = try service.createLinks(to: sources, in: destination, kind: settings.symlinkKind)
            try recents.remember(destination)
            context.completeRequest(returningItems: [], completionHandler: nil)
        } catch {
            context.cancelRequest(withError: error)
        }
    }
}
