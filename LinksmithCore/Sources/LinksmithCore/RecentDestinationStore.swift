import Foundation

public struct RecentDestination: Codable, Equatable, Sendable {
    public let displayName: String
    public let bookmarkData: Data
    public let lastUsedAt: Date

    public init(displayName: String, bookmarkData: Data, lastUsedAt: Date) {
        self.displayName = displayName
        self.bookmarkData = bookmarkData
        self.lastUsedAt = lastUsedAt
    }
}

public final class RecentDestinationStore: @unchecked Sendable {
    private enum Key { static let destinations = "recentDestinations" }
    private let defaults: UserDefaults
    private let limit: Int

    public init(
        defaults: UserDefaults? = UserDefaults(suiteName: LinksmithSharedStorage.appGroupIdentifier),
        limit: Int = 10
    ) {
        self.defaults = defaults ?? .standard
        self.limit = max(1, limit)
    }

    public func resolvedURLs() -> [URL] {
        records().compactMap { record in
            var stale = false
            guard let url = try? URL(
                resolvingBookmarkData: record.bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            ) else { return nil }
            return url
        }
    }

    public func remember(_ url: URL, now: Date = Date()) throws {
        let normalized = url.standardizedFileURL
        let bookmark = try normalized.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: [.nameKey],
            relativeTo: nil
        )
        var current = Array(zip(records(), resolvedURLs()))
        current.removeAll { $0.1.standardizedFileURL == normalized }
        let record = RecentDestination(
            displayName: normalized.lastPathComponent.isEmpty ? normalized.path : normalized.lastPathComponent,
            bookmarkData: bookmark,
            lastUsedAt: now
        )
        let updated = [record] + current.map(\.0)
        defaults.set(try PropertyListEncoder().encode(Array(updated.prefix(limit))), forKey: Key.destinations)
    }

    public func records() -> [RecentDestination] {
        guard let data = defaults.data(forKey: Key.destinations) else { return [] }
        return (try? PropertyListDecoder().decode([RecentDestination].self, from: data)) ?? []
    }
}
