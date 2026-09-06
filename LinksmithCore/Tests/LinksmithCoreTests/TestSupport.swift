import Foundation
import Testing

func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
    let suiteName = "LinksmithCoreTests.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer {
        defaults.removePersistentDomain(forName: suiteName)
    }
    try body(defaults)
}
