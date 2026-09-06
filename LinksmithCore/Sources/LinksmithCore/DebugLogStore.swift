import Foundation

public struct DebugLogEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let process: String
    public let message: String

    public init(id: UUID = UUID(), date: Date = Date(), process: String, message: String) {
        self.id = id
        self.date = date
        self.process = process
        self.message = message
    }
}

public final class DebugLogStore: @unchecked Sendable {
    private enum Key { static let entries = "debugLogEntries" }
    private let defaults: UserDefaults
    private let limit: Int

    public init(
        defaults: UserDefaults? = UserDefaults(suiteName: LinksmithSharedStorage.appGroupIdentifier),
        limit: Int = 200
    ) {
        self.defaults = defaults ?? .standard
        self.limit = max(1, limit)
    }

    public func append(_ message: String, process: String) {
        var updated = entries()
        updated.append(DebugLogEntry(process: process, message: message))
        defaults.set(try? PropertyListEncoder().encode(Array(updated.suffix(limit))), forKey: Key.entries)
        defaults.synchronize()
    }

    public func entries() -> [DebugLogEntry] {
        guard let data = defaults.data(forKey: Key.entries),
              let entries = try? PropertyListDecoder().decode([DebugLogEntry].self, from: data) else {
            return []
        }
        return entries
    }

    public func clear() {
        defaults.removeObject(forKey: Key.entries)
        defaults.synchronize()
    }
}
