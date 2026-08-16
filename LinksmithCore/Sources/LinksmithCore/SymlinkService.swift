import Foundation

public enum SymlinkKind: String, Codable, Sendable {
    case relative
    case absolute
}

public struct CreatedSymlink: Equatable, Sendable {
    public let source: URL
    public let link: URL
    public let targetPath: String

    public init(source: URL, link: URL, targetPath: String) {
        self.source = source
        self.link = link
        self.targetPath = targetPath
    }
}

public struct SymlinkService {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func targetPath(for source: URL, linkIn destination: URL, kind: SymlinkKind) -> String {
        let source = source.standardizedFileURL
        guard kind == .relative else { return source.path }

        let baseComponents = destination.standardizedFileURL.pathComponents
        let sourceComponents = source.pathComponents
        var sharedCount = 0

        while sharedCount < min(baseComponents.count, sourceComponents.count),
              baseComponents[sharedCount] == sourceComponents[sharedCount] {
            sharedCount += 1
        }

        let upward = Array(repeating: "..", count: baseComponents.count - sharedCount)
        let downward = Array(sourceComponents.dropFirst(sharedCount))
        let components = upward + downward
        return components.isEmpty ? "." : components.joined(separator: "/")
    }

    public func availableLinkURL(for source: URL, in destination: URL) -> URL {
        let initial = destination.appendingPathComponent(source.lastPathComponent)
        guard fileManager.fileExists(atPath: initial.path) == false else {
            let name = source.deletingPathExtension().lastPathComponent
            let pathExtension = source.pathExtension
            var suffix = 2

            while true {
                let candidateName = pathExtension.isEmpty
                    ? "\(name) \(suffix)"
                    : "\(name) \(suffix).\(pathExtension)"
                let candidate = destination.appendingPathComponent(candidateName)
                if fileManager.fileExists(atPath: candidate.path) == false {
                    return candidate
                }
                suffix += 1
            }
        }
        return initial
    }

    @discardableResult
    public func createLinks(
        to sources: [URL],
        in destination: URL,
        kind: SymlinkKind = .relative
    ) throws -> [CreatedSymlink] {
        guard sources.isEmpty == false else { throw LinksmithError.noSources }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: destination.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw LinksmithError.destinationIsNotDirectory(destination)
        }

        return try sources.map { source in
            guard fileManager.fileExists(atPath: source.path) else {
                throw LinksmithError.sourceDoesNotExist(source)
            }

            let link = availableLinkURL(for: source, in: destination)
            let target = targetPath(for: source, linkIn: destination, kind: kind)
            do {
                try fileManager.createSymbolicLink(atPath: link.path, withDestinationPath: target)
            } catch {
                throw LinksmithError.unableToCreateLink(link, error.localizedDescription)
            }
            return CreatedSymlink(source: source, link: link, targetPath: target)
        }
    }
}
