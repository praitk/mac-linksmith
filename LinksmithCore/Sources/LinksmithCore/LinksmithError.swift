import Foundation

public enum LinksmithError: LocalizedError, Equatable {
    case noSources
    case sourceDoesNotExist(URL)
    case sourceMustBeFile(URL)
    case sourceAlreadyLinksToDestination(URL, URL)
    case destinationContainsLinkToSource(URL, URL)
    case destinationAlreadyContainsItemNamed(URL)
    case destinationIsNotDirectory(URL)
    case unableToReplaceDestinationLink(URL, String)
    case unableToMoveItem(URL, URL, String)
    case unableToCreateLink(URL, String)

    public var errorDescription: String? {
        switch self {
        case .noSources:
            "No files or folders were selected."
        case .sourceDoesNotExist(let url):
            "The selected item no longer exists: \(url.path)"
        case .sourceMustBeFile(let url):
            "The selected item must be a file: \(url.path)"
        case .sourceAlreadyLinksToDestination(let source, let target):
            "\(source.lastPathComponent) is already a symbolic link to \(target.path)."
        case .destinationContainsLinkToSource(let source, let link):
            "\(link.lastPathComponent) in the destination is already a symbolic link to \(source.path)."
        case .destinationAlreadyContainsItemNamed(let url):
            "The destination already contains another item named \(url.lastPathComponent)."
        case .destinationIsNotDirectory(let url):
            "The selected destination is not a folder: \(url.path)"
        case .unableToReplaceDestinationLink(let url, let reason):
            "Could not replace the existing symbolic link \(url.lastPathComponent): \(reason)"
        case .unableToMoveItem(let source, let destination, let reason):
            "Could not move \(source.lastPathComponent) to \(destination.deletingLastPathComponent().path): \(reason)"
        case .unableToCreateLink(let url, let reason):
            "Could not create \(url.lastPathComponent): \(reason)"
        }
    }
}
