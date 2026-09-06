import Foundation

public struct PendingLinkAction: Codable, Equatable, Sendable {
    public let id: UUID
    public let selectedPaths: [String]
    public let selectedBookmarks: [Data?]?
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        selectedPaths: [String],
        selectedBookmarks: [Data?]? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.selectedPaths = selectedPaths
        self.selectedBookmarks = selectedBookmarks
        self.createdAt = createdAt
    }
}

public final class PendingLinkActionStore: @unchecked Sendable {
    private enum Key { static let pendingAction = "pendingLinkAction" }
    private let defaults: UserDefaults

    public init(defaults: UserDefaults? = UserDefaults(suiteName: LinksmithSharedStorage.appGroupIdentifier)) {
        self.defaults = defaults ?? .standard
    }

    public func saveSelection(_ urls: [URL], now: Date = Date()) throws {
        let normalized = urls.map(\.standardizedFileURL)
        let paths = normalized.map(\.path)
        let bookmarks = normalized.map { url in
            try? url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        }
        let action = PendingLinkAction(selectedPaths: paths, selectedBookmarks: bookmarks, createdAt: now)
        defaults.set(try PropertyListEncoder().encode(action), forKey: Key.pendingAction)
        defaults.synchronize()
    }

    public func consumeSelection() -> [URL] {
        guard let data = defaults.data(forKey: Key.pendingAction) else {
            return []
        }

        let action: PendingLinkAction
        do {
            action = try PropertyListDecoder().decode(PendingLinkAction.self, from: data)
        } catch {
            defaults.removeObject(forKey: Key.pendingAction)
            defaults.synchronize()
            return []
        }

        defaults.removeObject(forKey: Key.pendingAction)
        defaults.synchronize()
        return action.selectedPaths.enumerated().map { index, path in
            guard let bookmark = action.selectedBookmarks?[safe: index] ?? nil else {
                return URL(fileURLWithPath: path)
            }

            var stale = false
            return (try? URL(
                resolvingBookmarkData: bookmark,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )) ?? URL(fileURLWithPath: path)
        }
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
