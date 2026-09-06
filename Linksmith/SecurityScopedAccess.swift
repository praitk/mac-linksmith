import Foundation

enum SecurityScopedAccess {
    static func withAccess<T>(to urls: [URL], _ body: () throws -> T) rethrows -> T {
        let access = urls.map { $0.startAccessingSecurityScopedResource() }
        defer {
            for (url, didStart) in zip(urls, access) where didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }

        return try body()
    }
}
