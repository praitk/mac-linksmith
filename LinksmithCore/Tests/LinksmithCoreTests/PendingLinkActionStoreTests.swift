import Foundation
import Testing
@testable import LinksmithCore

struct PendingLinkActionStoreTests {
    @Test func saveAndConsumeSelectionPreservesOrder() throws {
        try withDefaults { defaults in
            let store = PendingLinkActionStore(defaults: defaults)
            let first = URL(fileURLWithPath: "/tmp/Linksmith First")
            let second = URL(fileURLWithPath: "/tmp/Linksmith Second")

            try store.saveSelection([first, second])

            #expect(store.consumeSelection().map(\.path) == [first.path, second.path])
            #expect(store.consumeSelection().isEmpty)
        }
    }

    @Test func consumeSelectionSupportsPathOnlyPendingActions() throws {
        try withDefaults { defaults in
            let store = PendingLinkActionStore(defaults: defaults)
            let action = PendingLinkAction(selectedPaths: ["/tmp/Legacy Selection"])
            defaults.set(try PropertyListEncoder().encode(action), forKey: "pendingLinkAction")

            #expect(store.consumeSelection().map(\.path) == ["/tmp/Legacy Selection"])
        }
    }

    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suiteName = "LinksmithCoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        try body(defaults)
    }
}
