import Foundation

public enum LinksmithSharedStorage {
    public static let appGroupIdentifier = "group.com.praitk.Linksmith"
}

public final class SharedSettings: @unchecked Sendable {
    private enum Key { static let symlinkKind = "defaultSymlinkKind" }
    private let defaults: UserDefaults

    public init(defaults: UserDefaults? = UserDefaults(suiteName: LinksmithSharedStorage.appGroupIdentifier)) {
        self.defaults = defaults ?? .standard
    }

    public var symlinkKind: SymlinkKind {
        get { SymlinkKind(rawValue: defaults.string(forKey: Key.symlinkKind) ?? "") ?? .relative }
        set { defaults.set(newValue.rawValue, forKey: Key.symlinkKind) }
    }
}
