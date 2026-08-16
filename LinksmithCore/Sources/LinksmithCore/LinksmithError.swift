import Foundation

public enum LinksmithError: LocalizedError, Equatable {
    case noSources
    case sourceDoesNotExist(URL)
    case destinationIsNotDirectory(URL)
    case unableToCreateLink(URL, String)

    public var errorDescription: String? {
        switch self {
        case .noSources:
            "No files or folders were selected."
        case .sourceDoesNotExist(let url):
            "The selected item no longer exists: \(url.path)"
        case .destinationIsNotDirectory(let url):
            "The selected destination is not a folder: \(url.path)"
        case .unableToCreateLink(let url, let reason):
            "Could not create \(url.lastPathComponent): \(reason)"
        }
    }
}
