import Foundation
import Testing
@testable import LinksmithCore

struct RecentDestinationStoreTests {
    @Test func rememberStoresDisplayNameAndResolvesURL() throws {
        try withTemporaryDirectory { root in
            try withDefaults { defaults in
                let destination = root.appendingPathComponent("Links", isDirectory: true)
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                let store = makeStore(defaults: defaults)

                try store.remember(destination)

                #expect(store.records().map(\.displayName) == ["Links"])
                #expect(store.resolvedURLs().map { $0.standardizedFileURL } == [destination.standardizedFileURL])
            }
        }
    }

    @Test func rememberMovesExistingDestinationToFront() throws {
        try withTemporaryDirectory { root in
            try withDefaults { defaults in
                let first = root.appendingPathComponent("First", isDirectory: true)
                let second = root.appendingPathComponent("Second", isDirectory: true)
                try FileManager.default.createDirectory(at: first, withIntermediateDirectories: true)
                try FileManager.default.createDirectory(at: second, withIntermediateDirectories: true)
                let store = makeStore(defaults: defaults)

                try store.remember(first)
                try store.remember(second)
                try store.remember(first)

                #expect(store.resolvedURLs().map(\.lastPathComponent) == ["First", "Second"])
            }
        }
    }

    @Test func rememberKeepsMostRecentDestinationsWithinLimit() throws {
        try withTemporaryDirectory { root in
            try withDefaults { defaults in
                let store = makeStore(defaults: defaults, limit: 2)
                let destinations = ["One", "Two", "Three"].map {
                    root.appendingPathComponent($0, isDirectory: true)
                }
                for destination in destinations {
                    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                    try store.remember(destination)
                }

                #expect(store.resolvedURLs().map(\.lastPathComponent) == ["Three", "Two"])
            }
        }
    }

    @Test func recordsReturnsEmptyForInvalidStoredData() throws {
        try withDefaults { defaults in
            defaults.set(Data("not a plist".utf8), forKey: "recentDestinations")

            #expect(RecentDestinationStore(defaults: defaults).records().isEmpty)
        }
    }

    @Test func resolvedURLsSkipsInvalidBookmarks() throws {
        try withDefaults { defaults in
            let record = RecentDestination(
                displayName: "Invalid",
                bookmarkData: Data("not a bookmark".utf8),
                lastUsedAt: Date()
            )
            defaults.set(try PropertyListEncoder().encode([record]), forKey: "recentDestinations")

            #expect(RecentDestinationStore(defaults: defaults).resolvedURLs().isEmpty)
        }
    }

    private func makeStore(defaults: UserDefaults, limit: Int = 10) -> RecentDestinationStore {
        RecentDestinationStore(
            defaults: defaults,
            limit: limit,
            makeBookmarkData: { Data($0.path.utf8) },
            resolveBookmarkData: { data in
                guard let path = String(data: data, encoding: .utf8) else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                return URL(fileURLWithPath: path)
            }
        )
    }
}
