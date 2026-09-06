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
        }
    }

    private func chooseMode(for selection: [URL]) -> LinkActionMode? {
        guard selection.count == 1, isDirectory(selection[0]) else {
            return .symlinkFromSelection
        }

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

    private func createLinksFromSelection(_ sources: [URL]) {
        diagnostics?.log("Presenting destination chooser for \(sources.count) source item(s).")
        guard let destination = chooseDestination() else {
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

    private func chooseDestination() -> URL? {
        let panel = NSOpenPanel()
        panel.title = "APP HANDOFF - Choose Destination Folder"
        panel.message = "Choose where symbolic links should be created."
        panel.prompt = "Create Links"
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

    private func createLinks(to sources: [URL], in destination: URL, rememberDestination: Bool) {
        let scopedURLs = sources + [destination]
        let access = scopedURLs.map { $0.startAccessingSecurityScopedResource() }
        defer {
            for (url, didStart) in zip(scopedURLs, access) where didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            diagnostics?.log("Creating \(sources.count) link(s) in \(destination.path).")
            let created = try service.createLinks(
                to: sources,
                in: destination,
                kind: settings.symlinkKind,
                validatesSourcesExist: false
            )
            if rememberDestination {
                try recents.remember(destination)
                diagnostics?.log("Remembered recent destination: \(destination.path)")
            }
            created.forEach { item in
                diagnostics?.log("Created link: \(item.link.path) -> \(item.targetPath)")
            }
            showCompletion(createdCount: created.count)
        } catch {
            diagnostics?.log("Failed creating links: \(error.localizedDescription)")
            showError(error)
        }
    }

    private func isDirectory(_ url: URL) -> Bool {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }

        var isDirectory: ObjCBool = false
        return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) && isDirectory.boolValue
    }

    private func showCompletion(createdCount: Int) {
        let alert = NSAlert()
        alert.messageText = "Links Created"
        alert.informativeText = "Created \(createdCount) symbolic \(createdCount == 1 ? "link" : "links")."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
    }
}

private enum LinkActionMode {
    case symlinkFromSelection
    case symlinkToSelectedFolder
}

private enum LinksmithActionError: LocalizedError {
    case destinationMustBeSingleFolder

    var errorDescription: String? {
        switch self {
        case .destinationMustBeSingleFolder:
            "Select one folder to create symbolic links into."
        }
    }
}
