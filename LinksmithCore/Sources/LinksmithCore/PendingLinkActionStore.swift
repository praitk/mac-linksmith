import Foundation

public struct PendingLinkAction: Codable, Equatable, Sendable {
    public let id: UUID
    public let selectedPaths: [String]
    public let createdAt: Date

    public init(id: UUID = UUID(), selectedPaths: [String], createdAt: Date = Date()) {
        self.id = id
        self.selectedPaths = selectedPaths
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
        let paths = urls.map { $0.standardizedFileURL.path }
        let action = PendingLinkAction(selectedPaths: paths, createdAt: now)
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
        return action.selectedPaths.map { URL(fileURLWithPath: $0) }
    }
}
