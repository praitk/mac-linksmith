import AppKit
import LinksmithCore

@MainActor
final class LinkWorkflowRunner {
    private let pendingActions = PendingLinkActionStore()
    private let settings = SharedSettings()
    private let recents = RecentDestinationStore()
    private let service = SymlinkService()
    private let diagnostics: DebugDiagnostics?
    private var recentDestinationURLs: [URL] = []
    private weak var destinationPanel: NSOpenPanel?

    init(diagnostics: DebugDiagnostics? = nil) {
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
        }
    }

    private func chooseMode(for selection: [URL]) -> LinkActionMode? {
        guard selection.count == 1 else {
            return .symlinkFromSelection
        }

        if isDirectory(selection[0]) {
            return chooseSingleFolderMode()
        }

        return chooseSingleFileMode()
    }

    private func chooseSingleFolderMode() -> LinkActionMode? {
        let alert = NSAlert()
        alert.messageText = "Create Symbolic Links"
        alert.informativeText = "Create symbolic links inside the selected folder, or create a symbolic link to the folder itself."
        alert.addButton(withTitle: "Create Links Here")
        alert.addButton(withTitle: "Link to This Folder")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .symlinkToSelectedFolder
        case .alertSecondButtonReturn:
            return .symlinkFromSelection
        default:
            return nil
        }
    }

    private func chooseSingleFileMode() -> LinkActionMode? {
        let alert = NSAlert()
        alert.messageText = "Create Symbolic Link"
        alert.informativeText = "Create a symbolic link to the selected file, or move the file to a folder and replace it with a symbolic link."
        alert.addButton(withTitle: "Create Link Elsewhere")
        alert.addButton(withTitle: "Move and Replace with Link")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .symlinkFromSelection
        case .alertSecondButtonReturn:
            return .moveSelectionAndReplaceWithSymlink
        default:
            return nil
        }
    }

    private func createLinksFromSelection(_ sources: [URL]) {
        diagnostics?.log("Presenting destination chooser for \(sources.count) source item(s).")
        guard let destination = chooseDestination(
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
            showError(LinksmithActionError.destinationMustBeSingleFolder)
            return
        }

        diagnostics?.log("Presenting source chooser for destination: \(destination.path)")
        guard let sources = chooseSources() else {
            diagnostics?.log("User cancelled source chooser.")
            return
        }
        diagnostics?.log("User selected \(sources.count) source item(s).")
        createLinks(to: sources, in: destination, rememberDestination: false)
    }

    private func moveSelectionAndReplaceWithSymlink(_ source: URL) {
        diagnostics?.log("Presenting move destination chooser for: \(source.path)")
        guard let destination = chooseDestination(
            message: "Choose where the file should be moved before Linksmith replaces it with a symbolic link.",
            prompt: "Move File"
        ) else {
            diagnostics?.log("User cancelled move destination chooser.")
            return
        }

        guard let originalFolder = authorizeOriginalFolder(for: source) else {
            diagnostics?.log("User cancelled original folder authorization.")
            return
        }

        moveAndReplace(source: source, destination: destination, additionalScopedURLs: [originalFolder])
    }

    private func chooseDestination(message: String, prompt: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = "APP HANDOFF - Choose Destination Folder"
        panel.message = message
        panel.prompt = prompt
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        configureRecentDestinationsAccessory(for: panel)
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func configureRecentDestinationsAccessory(for panel: NSOpenPanel) {
        recentDestinationURLs = recents.resolvedURLs()
        panel.directoryURL = recentDestinationURLs.first
        destinationPanel = panel

        guard recentDestinationURLs.isEmpty == false else { return }

        let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 420, height: 26))
        popup.addItem(withTitle: "Recent destinations")
        popup.lastItem?.isEnabled = false
        recentDestinationURLs.forEach { popup.addItem(withTitle: $0.path(percentEncoded: false)) }
        popup.target = self
        popup.action = #selector(selectRecentDestination(_:))
        panel.accessoryView = popup
    }

    @objc private func selectRecentDestination(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem - 1
        guard recentDestinationURLs.indices.contains(index) else { return }

        let url = recentDestinationURLs[index]
        diagnostics?.log("Recent destination selected: \(url.path)")
        destinationPanel?.directoryURL = url
    }

    private func chooseSources() -> [URL]? {
        let panel = NSOpenPanel()
        panel.title = "APP HANDOFF - Choose Items to Link"
        panel.message = "Choose the files and folders that should be linked into the selected Finder folder."
        panel.prompt = "Choose Items"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = false
        return panel.runModal() == .OK ? panel.urls : nil
    }

    private func authorizeOriginalFolder(for source: URL) -> URL? {
        let originalFolder = source.deletingLastPathComponent().standardizedFileURL
        let panel = NSOpenPanel()
        panel.title = "APP HANDOFF - Authorize Original Folder"
        panel.message = "Choose \(originalFolder.lastPathComponent) so Linksmith can replace the original file with a symbolic link."
        panel.prompt = "Authorize"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = originalFolder

        guard panel.runModal() == .OK, let selected = panel.url?.standardizedFileURL else {
            return nil
        }

        guard selected == originalFolder else {
            showError(LinksmithActionError.originalFolderAuthorizationMismatch(originalFolder))
            return nil
        }

        return selected
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
            showCompletion(created)
        } catch {
            diagnostics?.log("Failed creating links: \(error.localizedDescription)")
            showError(error)
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
                guard confirmDestinationSymlinkReplacement() else {
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
                    showError(error)
                }
                return
            }

            diagnostics?.log("Failed moving and replacing with link: \(error.localizedDescription)")
            showError(error)
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
        showReplacementCompletion(replaced)
    }

    private func confirmDestinationSymlinkReplacement() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Destination Already Contains a Link to the Same File"
        alert.informativeText = "The destination contains a symbolic link to the selected file. Swap files by replacing that destination link with the moved file and creating a new link at the original location?"
        alert.addButton(withTitle: "Swap Files")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func isDirectory(_ url: URL) -> Bool {
        SecurityScopedAccess.withAccess(to: [url]) {
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
    }

    private func showCompletion(_ created: [CreatedSymlink]) {
        let content = LinkCompletionAlertContent.createdLinks(created)
        let alert = NSAlert()
        alert.messageText = content.message
        alert.informativeText = content.informativeText
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showReplacementCompletion(_ replaced: ReplacedItemSymlink) {
        let content = LinkCompletionAlertContent.replacedItem(replaced)
        let alert = NSAlert()
        alert.messageText = content.message
        alert.informativeText = content.informativeText
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
    }
}

struct LinkCompletionAlertContent: Equatable {
    let message: String
    let informativeText: String

    static func createdLinks(_ created: [CreatedSymlink]) -> LinkCompletionAlertContent {
        if let item = created.onlyElement {
            return LinkCompletionAlertContent(
                message: "Link Created",
                informativeText: "Created \(linkStyle(for: item.targetPath)) symbolic link: \(item.link.lastPathComponent)."
            )
        }

        let names = created
            .map { "\($0.link.lastPathComponent) (\(linkStyle(for: $0.targetPath)))" }
            .joined(separator: "\n")
        return LinkCompletionAlertContent(
            message: "Links Created",
            informativeText: "Created \(created.count) symbolic links:\n\(names)"
        )
    }

    static func replacedItem(_ replaced: ReplacedItemSymlink) -> LinkCompletionAlertContent {
        LinkCompletionAlertContent(
            message: "File Moved",
            informativeText: "Moved \(replaced.movedItem.lastPathComponent) and created \(linkStyle(for: replaced.targetPath)) symbolic link: \(replaced.original.lastPathComponent)."
        )
    }

    private static func linkStyle(for targetPath: String) -> String {
        targetPath.hasPrefix("/") ? "absolute" : "relative"
    }
}

private extension Collection {
    var onlyElement: Element? {
        count == 1 ? first : nil
    }
}

private enum LinkActionMode {
    case symlinkFromSelection
    case symlinkToSelectedFolder
    case moveSelectionAndReplaceWithSymlink
}

private enum SecurityScopedAccess {
    static func withAccess<T>(to urls: [URL], _ body: () throws -> T) rethrows -> T {
        let access = urls.map { $0.startAccessingSecurityScopedResource() }
        defer {
            for (url, didStart) in zip(urls, access) where didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return try body()
    }
}

private enum LinksmithActionError: LocalizedError {
    case destinationMustBeSingleFolder
    case originalFolderAuthorizationMismatch(URL)

    var errorDescription: String? {
        switch self {
        case .destinationMustBeSingleFolder:
            "Select one folder to create symbolic links into."
        case .originalFolderAuthorizationMismatch(let folder):
            "Choose the original folder to continue: \(folder.path)"
        }
    }
}
