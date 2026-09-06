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
    private let makeBookmarkData: (URL) throws -> Data
    private let resolveBookmarkData: (Data) throws -> URL

    public init(
        defaults: UserDefaults? = UserDefaults(suiteName: LinksmithSharedStorage.appGroupIdentifier),
        limit: Int = 10,
        makeBookmarkData: @escaping (URL) throws -> Data = { url in
            try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: [.nameKey],
                relativeTo: nil
            )
        },
        resolveBookmarkData: @escaping (Data) throws -> URL = { bookmarkData in
            var stale = false
            return try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
        }
    ) {
        self.defaults = defaults ?? .standard
        self.limit = max(1, limit)
        self.makeBookmarkData = makeBookmarkData
        self.resolveBookmarkData = resolveBookmarkData
    }

    public func resolvedURLs() -> [URL] {
        records().compactMap { record in
            try? resolveBookmarkData(record.bookmarkData)
        }
    }

    public func remember(_ url: URL, now: Date = Date()) throws {
        let normalized = url.standardizedFileURL
        let bookmark = try makeBookmarkData(normalized)
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
