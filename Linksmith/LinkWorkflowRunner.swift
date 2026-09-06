import Foundation
import LinksmithCore

@MainActor
final class LinkWorkflowRunner {
    private let pendingActions: PendingLinkActionStore
    private let settings: SharedSettings
    private let recents: RecentDestinationStore
    private let service: SymlinkService
    private let presenter: any LinkWorkflowPresenting
    private let diagnostics: DebugDiagnostics?

    init(
        pendingActions: PendingLinkActionStore = PendingLinkActionStore(),
        settings: SharedSettings = SharedSettings(),
        recents: RecentDestinationStore = RecentDestinationStore(),
        service: SymlinkService = SymlinkService(),
        presenter: (any LinkWorkflowPresenting)? = nil,
        diagnostics: DebugDiagnostics? = nil
    ) {
        self.pendingActions = pendingActions
        self.settings = settings
        self.recents = recents
        self.service = service
        self.presenter = presenter ?? AppKitLinkWorkflowPresenter(recents: recents, diagnostics: diagnostics)
        self.diagnostics = diagnostics
    }

    func performPendingActionIfAvailable() {
        let selection = pendingActions.consumeSelection()
        guard selection.isEmpty == false else { return }

        diagnostics?.log("Consumed Finder handoff with \(selection.count) selected item(s).")

        guard let mode = chooseMode(for: selection) else {
            diagnostics?.log("User cancelled mode selection.")
            return
        }

        switch mode {
        case .symlinkFromSelection:
            diagnostics?.log("Mode selected: From Selection.")
            createLinksFromSelection(selection)
        case .symlinkToSelectedFolder:
            diagnostics?.log("Mode selected: To This Folder.")
            createLinksToSelectedFolder(selection[0])
        case .moveSelectionAndReplaceWithSymlink:
            diagnostics?.log("Mode selected: Move and Replace with Link.")
            moveSelectionAndReplaceWithSymlink(selection[0])
        case .swapSymlinkTarget:
            diagnostics?.log("Mode selected: Swap Symlink Target.")
            swapSymlinkTarget(selection[0])
        case .copySymlinkTargetReplacingLink:
            diagnostics?.log("Mode selected: Copy Symlink Target.")
            copySymlinkTargetReplacingLink(selection[0])
        case .moveSymlinkTargetReplacingLink:
            diagnostics?.log("Mode selected: Move Symlink Target.")
            moveSymlinkTargetReplacingLink(selection[0])
        }
    }

    private func chooseMode(for selection: [URL]) -> LinkActionMode? {
        LinkWorkflowModeResolver.mode(
            for: selection,
            isSymbolicLink: isSymbolicLink,
            isDirectory: isDirectory,
            chooseSymlinkMode: presenter.chooseSymlinkMode,
            chooseSingleFolderMode: presenter.chooseSingleFolderMode,
            chooseSingleFileMode: presenter.chooseSingleFileMode
        )
    }

    private func createLinksFromSelection(_ sources: [URL]) {
        diagnostics?.log("Presenting destination chooser for \(sources.count) source item(s).")
        guard let destination = presenter.chooseDestination(
            message: "Choose where symbolic links should be created.",
            prompt: "Create Links"
        ) else {
            diagnostics?.log("User cancelled destination chooser.")
            return
        }
        diagnostics?.log("Destination selected: \(destination.path)")
        createLinks(to: sources, in: destination, rememberDestination: true)
    }

    private func createLinksToSelectedFolder(_ destination: URL) {
        guard isDirectory(destination) else {
            diagnostics?.log("Selected destination is not a folder: \(destination.path)")
            presenter.showError(LinksmithActionError.destinationMustBeSingleFolder)
            return
        }

        diagnostics?.log("Presenting source chooser for destination: \(destination.path)")
        guard let sources = presenter.chooseSources() else {
            diagnostics?.log("User cancelled source chooser.")
            return
        }
        diagnostics?.log("User selected \(sources.count) source item(s).")
        createLinks(to: sources, in: destination, rememberDestination: false)
    }

    private func moveSelectionAndReplaceWithSymlink(_ source: URL) {
        diagnostics?.log("Presenting move destination chooser for: \(source.path)")
        guard let destination = presenter.chooseDestination(
            message: "Choose where the file should be moved before Linksmith replaces it with a symbolic link.",
            prompt: "Move File"
        ) else {
            diagnostics?.log("User cancelled move destination chooser.")
            return
        }

        guard let originalFolder = presenter.authorizeOriginalFolder(for: source) else {
            diagnostics?.log("User cancelled original folder authorization.")
            return
        }

        moveAndReplace(source: source, destination: destination, additionalScopedURLs: [originalFolder])
    }

    private func swapSymlinkTarget(_ link: URL) {
        let scopedURLs: [URL]
        do {
            scopedURLs = try authorizeSymlinkReplacement(link)
        } catch {
            diagnostics?.log("Failed preparing symlink replacement authorization: \(error.localizedDescription)")
            presenter.showError(error)
            return
        }
        guard scopedURLs.isEmpty == false else { return }

        do {
            let swapped = try SecurityScopedAccess.withAccess(to: scopedURLs) {
                diagnostics?.log("Swapping symlink target with selected link: \(link.path)")
                return try service.swapTargetWithSymlink(at: link, kind: settings.symlinkKind)
            }
            diagnostics?.log("Moved target into place: \(swapped.movedItem.path)")
            diagnostics?.log("Created replacement link: \(swapped.replacementSymbolicLink.path) -> \(swapped.replacementTargetPath)")
            presenter.showSwappedSymlinkTargetCompletion(swapped)
        } catch {
            diagnostics?.log("Failed swapping symlink target: \(error.localizedDescription)")
            presenter.showError(error)
        }
    }

    private func copySymlinkTargetReplacingLink(_ link: URL) {
        let scopedURLs: [URL]
        do {
            scopedURLs = try authorizeSymlinkReplacement(link)
        } catch {
            diagnostics?.log("Failed preparing symlink replacement authorization: \(error.localizedDescription)")
            presenter.showError(error)
            return
        }
        guard scopedURLs.isEmpty == false else { return }

        do {
            let replaced = try SecurityScopedAccess.withAccess(to: scopedURLs) {
                diagnostics?.log("Copying symlink target over selected link: \(link.path)")
                return try service.copyTargetReplacingSymlink(at: link)
            }
            diagnostics?.log("Copied target \(replaced.resolvedTarget.path) over link \(replaced.symbolicLink.path)")
            presenter.showCopiedSymlinkTargetCompletion(replaced)
        } catch {
            diagnostics?.log("Failed copying symlink target: \(error.localizedDescription)")
            presenter.showError(error)
        }
    }

    private func moveSymlinkTargetReplacingLink(_ link: URL) {
        let scopedURLs: [URL]
        do {
            scopedURLs = try authorizeSymlinkReplacement(link)
        } catch {
            diagnostics?.log("Failed preparing symlink replacement authorization: \(error.localizedDescription)")
            presenter.showError(error)
            return
        }
        guard scopedURLs.isEmpty == false else { return }

        do {
            let replaced = try SecurityScopedAccess.withAccess(to: scopedURLs) {
                diagnostics?.log("Moving symlink target over selected link: \(link.path)")
                return try service.moveTargetReplacingSymlink(at: link)
            }
            diagnostics?.log("Moved target \(replaced.resolvedTarget.path) over link \(replaced.symbolicLink.path)")
            presenter.showMovedSymlinkTargetCompletion(replaced)
        } catch {
            diagnostics?.log("Failed moving symlink target: \(error.localizedDescription)")
            presenter.showError(error)
        }
    }

    private func authorizeSymlinkReplacement(_ link: URL) throws -> [URL] {
        let authorizationDirectories = try service.authorizationDirectoriesForReplacingSymlink(at: link)
        var scopedURLs = [link]

        for directory in authorizationDirectories {
            guard let authorizedDirectory = presenter.authorizeSymlinkReplacementFolder(directory, for: link) else {
                diagnostics?.log("User cancelled symbolic link replacement authorization for \(directory.path).")
                return []
            }
            scopedURLs.append(authorizedDirectory)
        }

        return scopedURLs
    }

    private func createLinks(to sources: [URL], in destination: URL, rememberDestination: Bool) {
        do {
            let created = try SecurityScopedAccess.withAccess(to: sources + [destination]) {
                diagnostics?.log("Creating \(sources.count) link(s) in \(destination.path).")
                return try service.createLinks(
                    to: sources,
                    in: destination,
                    kind: settings.symlinkKind,
                    sourceValidation: .allowUnresolvedSources
                )
            }
            if rememberDestination {
                try recents.remember(destination)
                diagnostics?.log("Remembered recent destination: \(destination.path)")
            }
            created.forEach { item in
                diagnostics?.log("Created link: \(item.link.path) -> \(item.targetPath)")
            }
            presenter.showCompletion(created)
        } catch {
            diagnostics?.log("Failed creating links: \(error.localizedDescription)")
            presenter.showError(error)
        }
    }

    private func moveAndReplace(
        source: URL,
        destination: URL,
        additionalScopedURLs: [URL] = [],
        replacesExistingDestinationSymlink: Bool = false
    ) {
        do {
            let replaced = try runMoveAndReplace(
                source: source,
                destination: destination,
                additionalScopedURLs: additionalScopedURLs,
                replacesExistingDestinationSymlink: replacesExistingDestinationSymlink
            )
            try handleSuccessfulReplacement(replaced, destination: destination)
        } catch {
            if let linkConflict = error as? LinksmithError,
               case .destinationContainsLinkToSource = linkConflict {
                guard presenter.confirmDestinationSymlinkReplacement() else {
                    diagnostics?.log("User cancelled destination symlink swap.")
                    return
                }

                diagnostics?.log("User chose to swap files for destination symlink conflict.")
                do {
                    let replaced = try runMoveAndReplace(
                        source: source,
                        destination: destination,
                        additionalScopedURLs: additionalScopedURLs,
                        replacesExistingDestinationSymlink: true
                    )
                    try handleSuccessfulReplacement(replaced, destination: destination)
                } catch {
                    diagnostics?.log("Failed swapping destination symlink: \(error.localizedDescription)")
                    presenter.showError(error)
                }
                return
            }

            diagnostics?.log("Failed moving and replacing with link: \(error.localizedDescription)")
            presenter.showError(error)
        }
    }

    private func runMoveAndReplace(
        source: URL,
        destination: URL,
        additionalScopedURLs: [URL],
        replacesExistingDestinationSymlink: Bool
    ) throws -> ReplacedItemSymlink {
        try SecurityScopedAccess.withAccess(to: [source, destination] + additionalScopedURLs) {
            diagnostics?.log("Moving \(source.path) to \(destination.path) and replacing original with a link.")
            return try service.moveItemAndReplaceWithLink(
                source: source,
                in: destination,
                kind: settings.symlinkKind,
                replacesExistingDestinationSymlink: replacesExistingDestinationSymlink
            )
        }
    }

    private func handleSuccessfulReplacement(_ replaced: ReplacedItemSymlink, destination: URL) throws {
        try recents.remember(destination)
        diagnostics?.log("Remembered recent destination: \(destination.path)")
        diagnostics?.log("Moved item: \(replaced.movedItem.path)")
        diagnostics?.log("Created replacement link: \(replaced.original.path) -> \(replaced.targetPath)")
        presenter.showReplacementCompletion(replaced)
    }

    private func isDirectory(_ url: URL) -> Bool {
        SecurityScopedAccess.withAccess(to: [url]) {
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
    }

    private func isSymbolicLink(_ url: URL) -> Bool {
        SecurityScopedAccess.withAccess(to: [url]) {
            service.symbolicLinkTargetPath(at: url) != nil
        }
    }

}
