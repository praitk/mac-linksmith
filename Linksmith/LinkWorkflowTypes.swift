import Foundation
import LinksmithCore

enum LinkActionMode: Equatable {
    case symlinkFromSelection
    case symlinkToSelectedFolder
    case moveSelectionAndReplaceWithSymlink
    case swapSymlinkTarget
    case copySymlinkTargetReplacingLink
    case moveSymlinkTargetReplacingLink
}

enum LinkWorkflowModeResolver {
    static func mode(
        for selection: [URL],
        isSymbolicLink: (URL) -> Bool,
        isDirectory: (URL) -> Bool,
        chooseSymlinkMode: () -> LinkActionMode?,
        chooseSingleFolderMode: () -> LinkActionMode?,
        chooseSingleFileMode: () -> LinkActionMode?
    ) -> LinkActionMode? {
        guard selection.count == 1 else {
            return .symlinkFromSelection
        }

        if isSymbolicLink(selection[0]) {
            return chooseSymlinkMode()
        }

        return isDirectory(selection[0]) ? chooseSingleFolderMode() : chooseSingleFileMode()
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

    static func copiedSymlinkTarget(_ replaced: ReplacedSymlinkTarget) -> LinkCompletionAlertContent {
        LinkCompletionAlertContent(
            message: "File Copied",
            informativeText: "Copied \(replaced.resolvedTarget.lastPathComponent) and replaced symbolic link: \(replaced.symbolicLink.lastPathComponent)."
        )
    }

    static func movedSymlinkTarget(_ replaced: ReplacedSymlinkTarget) -> LinkCompletionAlertContent {
        LinkCompletionAlertContent(
            message: "File Moved",
            informativeText: "Moved \(replaced.resolvedTarget.lastPathComponent) and replaced symbolic link: \(replaced.symbolicLink.lastPathComponent)."
        )
    }

    static func swappedSymlinkTarget(_ swapped: SwappedSymlinkTarget) -> LinkCompletionAlertContent {
        LinkCompletionAlertContent(
            message: "Files Swapped",
            informativeText: "Moved \(swapped.movedItem.lastPathComponent) into place and created \(linkStyle(for: swapped.replacementTargetPath)) symbolic link: \(swapped.replacementSymbolicLink.lastPathComponent)."
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
