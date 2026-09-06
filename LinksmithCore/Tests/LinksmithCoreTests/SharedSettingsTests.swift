import Testing
@testable import LinksmithCore

struct SharedSettingsTests {
    @Test func symlinkKindDefaultsToRelative() throws {
        try withDefaults { defaults in
            let settings = SharedSettings(defaults: defaults)

            #expect(settings.symlinkKind == .relative)
        }
    }

    @Test func symlinkKindPersistsStoredValue() throws {
        try withDefaults { defaults in
            let settings = SharedSettings(defaults: defaults)

            settings.symlinkKind = .absolute

            #expect(SharedSettings(defaults: defaults).symlinkKind == .absolute)
        }
    }

    @Test func symlinkKindFallsBackToRelativeForInvalidStoredValue() throws {
        try withDefaults { defaults in
            defaults.set("invalid", forKey: "defaultSymlinkKind")

            #expect(SharedSettings(defaults: defaults).symlinkKind == .relative)
        }
    }
}
