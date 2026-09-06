import Foundation
import LinksmithCore

enum LinkActionMode: Equatable {
    case symlinkFromSelection
    case symlinkToSelectedFolder
    case moveSelectionAndReplaceWithSymlink
}

enum LinkWorkflowModeResolver {
    static func mode(
        for selection: [URL],
        isDirectory: (URL) -> Bool,
        chooseSingleFolderMode: () -> LinkActionMode?,
        chooseSingleFileMode: () -> LinkActionMode?
    ) -> LinkActionMode? {
        guard selection.count == 1 else {
            return .symlinkFromSelection
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

    private static func linkStyle(for targetPath: String) -> String {
        targetPath.hasPrefix("/") ? "absolute" : "relative"
    }
}

private extension Collection {
    var onlyElement: Element? {
        count == 1 ? first : nil
    }
}
