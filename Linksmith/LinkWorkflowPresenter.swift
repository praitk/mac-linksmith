import AppKit
import LinksmithCore

@MainActor
protocol LinkWorkflowPresenting {
    func chooseSymlinkMode() -> LinkActionMode?
    func chooseSingleFolderMode() -> LinkActionMode?
    func chooseSingleFileMode() -> LinkActionMode?
    func chooseDestination(message: String, prompt: String) -> URL?
    func chooseSources() -> [URL]?
    func authorizeOriginalFolder(for source: URL) -> URL?
    func authorizeSymlinkReplacementFolder(_ folder: URL, for link: URL) -> URL?
    func confirmDestinationSymlinkReplacement() -> Bool
    func showCompletion(_ created: [CreatedSymlink])
    func showReplacementCompletion(_ replaced: ReplacedItemSymlink)
    func showCopiedSymlinkTargetCompletion(_ replaced: ReplacedSymlinkTarget)
    func showMovedSymlinkTargetCompletion(_ replaced: ReplacedSymlinkTarget)
    func showSwappedSymlinkTargetCompletion(_ swapped: SwappedSymlinkTarget)
    func showError(_ error: Error)
}

@MainActor
final class AppKitLinkWorkflowPresenter: NSObject, LinkWorkflowPresenting {
    private let recents: RecentDestinationStore
    private let diagnostics: DebugDiagnostics?
    private var recentDestinationURLs: [URL] = []
    private weak var destinationPanel: NSOpenPanel?

    init(recents: RecentDestinationStore, diagnostics: DebugDiagnostics?) {
        self.recents = recents
        self.diagnostics = diagnostics
    }

    func chooseSymlinkMode() -> LinkActionMode? {
        let alert = NSAlert()
        alert.messageText = "Replace Symbolic Link"
        alert.informativeText = "Choose how Linksmith should replace the selected symbolic link using its target file. If the link is broken, the operation will fail without removing it."
        alert.addButton(withTitle: "Swap Files")
        alert.addButton(withTitle: "Copy File Here")
        alert.addButton(withTitle: "Move File Here")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .swapSymlinkTarget
        case .alertSecondButtonReturn:
            return .copySymlinkTargetReplacingLink
        case .alertThirdButtonReturn:
            return .moveSymlinkTargetReplacingLink
        default:
            return nil
        }
    }

    func chooseSingleFolderMode() -> LinkActionMode? {
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

    func chooseSingleFileMode() -> LinkActionMode? {
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

    func chooseDestination(message: String, prompt: String) -> URL? {
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

    func chooseSources() -> [URL]? {
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

    func authorizeOriginalFolder(for source: URL) -> URL? {
        let originalFolder = source.deletingLastPathComponent().standardizedFileURL
        return authorizeFolder(
            originalFolder,
            title: "APP HANDOFF - Authorize Original Folder",
            message: "Choose \(originalFolder.lastPathComponent) to authorize Linksmith to replace the original file with a symbolic link.",
            prompt: "Authorize",
            mismatchError: .originalFolderAuthorizationMismatch(originalFolder)
        )
    }

    func authorizeSymlinkReplacementFolder(_ folder: URL, for link: URL) -> URL? {
        let folder = folder.standardizedFileURL
        return authorizeFolder(
            folder,
            title: "APP HANDOFF - Authorize Symbolic Link Replacement",
            message: "Choose \(folder.lastPathComponent) to authorize Linksmith to replace the selected symbolic link.",
            prompt: "Authorize",
            mismatchError: .symlinkReplacementFolderAuthorizationMismatch(folder)
        )
    }

    private func authorizeFolder(
        _ folder: URL,
        title: String,
        message: String,
        prompt: String,
        mismatchError: LinksmithActionError
    ) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.message = message
        panel.prompt = prompt
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = folder

        guard panel.runModal() == .OK, let selected = panel.url?.standardizedFileURL else {
            return nil
        }

        guard selected == folder else {
            showError(mismatchError)
            return nil
        }

        return selected
    }

    func confirmDestinationSymlinkReplacement() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Destination Already Contains a Link to the Same File"
        alert.informativeText = "The destination contains a symbolic link to the selected file. Swap files by replacing that destination link with the moved file and creating a new link at the original location?"
        alert.addButton(withTitle: "Swap Files")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    func showCompletion(_ created: [CreatedSymlink]) {
        let content = LinkCompletionAlertContent.createdLinks(created)
        let alert = NSAlert()
        alert.messageText = content.message
        alert.informativeText = content.informativeText
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func showReplacementCompletion(_ replaced: ReplacedItemSymlink) {
        let content = LinkCompletionAlertContent.replacedItem(replaced)
        let alert = NSAlert()
        alert.messageText = content.message
        alert.informativeText = content.informativeText
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func showCopiedSymlinkTargetCompletion(_ replaced: ReplacedSymlinkTarget) {
        showAlert(content: LinkCompletionAlertContent.copiedSymlinkTarget(replaced))
    }

    func showMovedSymlinkTargetCompletion(_ replaced: ReplacedSymlinkTarget) {
        showAlert(content: LinkCompletionAlertContent.movedSymlinkTarget(replaced))
    }

    func showSwappedSymlinkTargetCompletion(_ swapped: SwappedSymlinkTarget) {
        showAlert(content: LinkCompletionAlertContent.swappedSymlinkTarget(swapped))
    }

    private func showAlert(content: LinkCompletionAlertContent) {
        let alert = NSAlert()
        alert.messageText = content.message
        alert.informativeText = content.informativeText
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    func showError(_ error: Error) {
        let alert = NSAlert(error: error)
        alert.runModal()
    }
}

enum LinksmithActionError: LocalizedError {
    case destinationMustBeSingleFolder
    case originalFolderAuthorizationMismatch(URL)
    case symlinkReplacementFolderAuthorizationMismatch(URL)

    var errorDescription: String? {
        switch self {
        case .destinationMustBeSingleFolder:
            "Select one folder to create symbolic links into."
        case .originalFolderAuthorizationMismatch(let folder):
            "Choose the original folder to continue: \(folder.path)"
        case .symlinkReplacementFolderAuthorizationMismatch(let folder):
            "Choose the requested symbolic link replacement folder to continue: \(folder.path)"
        }
    }
}
