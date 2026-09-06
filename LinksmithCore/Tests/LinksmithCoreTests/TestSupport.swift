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

func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: url) }
    try body(url)
}
