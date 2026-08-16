import AppKit

@MainActor
final class DestinationChooser: NSObject {
    private let panel = NSOpenPanel()
    private let recentURLs: [URL]

    init(recentURLs: [URL]) { self.recentURLs = recentURLs }

    func choose() -> URL? {
        panel.title = "Create Symlink…"
        panel.message = "Choose the folder where the symbolic link should be created."
        panel.prompt = "Create Symlink"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.directoryURL = recentURLs.first
        if recentURLs.isEmpty == false {
            let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 360, height: 26))
            popup.addItem(withTitle: "Recent destinations")
            popup.lastItem?.isEnabled = false
            recentURLs.forEach { popup.addItem(withTitle: $0.path(percentEncoded: false)) }
            popup.target = self
            popup.action = #selector(selectRecentDestination(_:))
            panel.accessoryView = popup
        }
        return panel.runModal() == .OK ? panel.url : nil
    }

    @objc private func selectRecentDestination(_ sender: NSPopUpButton) {
        let index = sender.indexOfSelectedItem - 1
        guard recentURLs.indices.contains(index) else { return }
        panel.directoryURL = recentURLs[index]
    }
}
