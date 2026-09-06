import Testing
@testable import LinksmithCore

struct DebugLogStoreTests {
    @Test func appendStoresEntriesInOrder() throws {
        try withDefaults { defaults in
            let store = DebugLogStore(defaults: defaults)

            store.append("first", process: "App")
            store.append("second", process: "Extension")

            let entries = store.entries()
            #expect(entries.map(\.message) == ["first", "second"])
            #expect(entries.map(\.process) == ["App", "Extension"])
        }
    }

    @Test func appendKeepsMostRecentEntriesWithinLimit() throws {
        try withDefaults { defaults in
            let store = DebugLogStore(defaults: defaults, limit: 2)

            store.append("one", process: "App")
            store.append("two", process: "App")
            store.append("three", process: "App")

            #expect(store.entries().map(\.message) == ["two", "three"])
        }
    }

    @Test func clearRemovesStoredEntries() throws {
        try withDefaults { defaults in
            let store = DebugLogStore(defaults: defaults)

            store.append("message", process: "App")
            store.clear()

            #expect(store.entries().isEmpty)
        }
    }
}
