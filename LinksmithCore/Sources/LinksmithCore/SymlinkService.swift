import Darwin
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

public struct ReplacedItemSymlink: Equatable, Sendable {
    public let original: URL
    public let movedItem: URL
    public let targetPath: String

    public init(original: URL, movedItem: URL, targetPath: String) {
        self.original = original
        self.movedItem = movedItem
        self.targetPath = targetPath
    }
}

public struct SymlinkService {
    private static let markerFileName = ".linksmith"

    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public func targetPath(for source: URL, linkIn destination: URL, kind: SymlinkKind) -> String {
        let source = source.standardizedFileURL
        let destination = destination.standardizedFileURL
        guard kind == .relative,
              shouldUseAbsoluteTarget(for: source, linkIn: destination) == false else {
            return source.path
        }

        let baseComponents = destination.pathComponents
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

    private func shouldUseAbsoluteTarget(for source: URL, linkIn destination: URL) -> Bool {
        let sourceDirectory = directoryForMarkerSearch(from: source)
        let destinationDirectory = destination.standardizedFileURL
        let sourceComponents = sourceDirectory.pathComponents
        let destinationComponents = destinationDirectory.pathComponents
        var sharedCount = 0

        while sharedCount < min(sourceComponents.count, destinationComponents.count),
              sourceComponents[sharedCount] == destinationComponents[sharedCount] {
            sharedCount += 1
        }

        guard sharedCount > 0 else { return false }

        return pathBelowCommonAncestorContainsMarker(
            components: sourceComponents,
            from: sourceComponents.count,
            above: sharedCount
        ) || pathBelowCommonAncestorContainsMarker(
            components: destinationComponents,
            from: destinationComponents.count,
            above: sharedCount
        )
    }

    private func directoryForMarkerSearch(from url: URL) -> URL {
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory),
           isDirectory.boolValue {
            return url.standardizedFileURL
        }

        return url.deletingLastPathComponent().standardizedFileURL
    }

    private func pathBelowCommonAncestorContainsMarker(components: [String], from start: Int, above commonAncestorCount: Int) -> Bool {
        guard start > commonAncestorCount else { return false }

        for count in stride(from: start, through: commonAncestorCount + 1, by: -1) {
            let directory = URL(fileURLWithPath: NSString.path(withComponents: Array(components.prefix(count))))
            let marker = directory.appendingPathComponent(Self.markerFileName)
            if fileManager.fileExists(atPath: marker.path) {
                return true
            }
        }

        return false
    }

    public func availableLinkURL(for source: URL, in destination: URL) -> URL {
        let initial = destination.appendingPathComponent(source.lastPathComponent)
        guard isPathAvailable(initial) == true else {
            let name = source.deletingPathExtension().lastPathComponent
            let pathExtension = source.pathExtension
            var suffix = 2

            while true {
                let candidateName = pathExtension.isEmpty
                    ? "\(name) \(suffix)"
                    : "\(name) \(suffix).\(pathExtension)"
                let candidate = destination.appendingPathComponent(candidateName)
                if isPathAvailable(candidate) {
                    return candidate
                }
                suffix += 1
            }
        }
        return initial
    }

    private func isPathAvailable(_ url: URL) -> Bool {
        if fileManager.fileExists(atPath: url.path) {
            return false
        }

        return (try? fileManager.destinationOfSymbolicLink(atPath: url.path)) == nil
    }

    private func symbolicLinkTarget(at url: URL) -> String? {
        try? fileManager.destinationOfSymbolicLink(atPath: url.path)
    }

    private func resolvedSymbolicLinkDestination(at url: URL) -> URL? {
        guard let target = symbolicLinkTarget(at: url) else {
            return nil
        }

        if target.hasPrefix("/") {
            return URL(fileURLWithPath: target).standardizedFileURL
        }

        return url.deletingLastPathComponent()
            .appendingPathComponent(target)
            .standardizedFileURL
    }

    private func refersToSameFile(_ first: URL, _ second: URL) -> Bool {
        if let firstID = fileResourceIdentifier(for: first),
           let secondID = fileResourceIdentifier(for: second) {
            return firstID.isEqual(secondID)
        }

        return first.standardizedFileURL.path == second.standardizedFileURL.path
    }

    private func fileResourceIdentifier(for url: URL) -> AnyObject? {
        try? url.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier as AnyObject
    }

    private func isChild(_ child: URL, of directory: URL) -> Bool {
        child.deletingLastPathComponent().standardizedFileURL.path == directory.standardizedFileURL.path
    }

    private func removeSymbolicLink(at url: URL) throws {
        guard unlink(url.path) == 0 else {
            throw LinksmithError.unableToReplaceDestinationLink(url, String(cString: strerror(errno)))
        }
    }

    private func moveFile(at source: URL, to destination: URL) throws {
        guard rename(source.path, destination.path) == 0 else {
            throw LinksmithError.unableToMoveItem(source, destination, String(cString: strerror(errno)))
        }
    }

    @discardableResult
    public func createLinks(
        to sources: [URL],
        in destination: URL,
        kind: SymlinkKind = .relative,
        validatesSourcesExist: Bool = true
    ) throws -> [CreatedSymlink] {
        guard sources.isEmpty == false else { throw LinksmithError.noSources }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: destination.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw LinksmithError.destinationIsNotDirectory(destination)
        }

        return try sources.map { source in
            guard validatesSourcesExist == false || fileManager.fileExists(atPath: source.path) else {
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

    @discardableResult
    public func moveItemAndReplaceWithLink(
        source: URL,
        in destination: URL,
        kind: SymlinkKind = .relative,
        replacesExistingDestinationSymlink: Bool = false
    ) throws -> ReplacedItemSymlink {
        let source = source.standardizedFileURL
        let destination = destination.standardizedFileURL

        if let linkedTarget = resolvedSymbolicLinkDestination(at: source),
           isChild(linkedTarget, of: destination) {
            throw LinksmithError.sourceAlreadyLinksToDestination(source, linkedTarget)
        }

        var sourceIsDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: source.path, isDirectory: &sourceIsDirectory) else {
            throw LinksmithError.sourceDoesNotExist(source)
        }
        guard sourceIsDirectory.boolValue == false else {
            throw LinksmithError.sourceMustBeFile(source)
        }

        var destinationIsDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: destination.path, isDirectory: &destinationIsDirectory),
              destinationIsDirectory.boolValue else {
            throw LinksmithError.destinationIsNotDirectory(destination)
        }

        let preferredDestination = destination.appendingPathComponent(source.lastPathComponent)
        var replacedDestinationLinkTarget: String?
        let movedItem: URL
        if let existingLinkTarget = resolvedSymbolicLinkDestination(at: preferredDestination),
           refersToSameFile(existingLinkTarget, source) {
            guard replacesExistingDestinationSymlink else {
                throw LinksmithError.destinationContainsLinkToSource(source, preferredDestination)
            }

            replacedDestinationLinkTarget = symbolicLinkTarget(at: preferredDestination)
            do {
                try removeSymbolicLink(at: preferredDestination)
            } catch {
                throw error
            }
            movedItem = preferredDestination
        } else {
            guard isPathAvailable(preferredDestination) else {
                throw LinksmithError.destinationAlreadyContainsItemNamed(preferredDestination)
            }
            movedItem = preferredDestination
        }

        do {
            try moveFile(at: source, to: movedItem)
        } catch {
            if let replacedDestinationLinkTarget {
                try? fileManager.createSymbolicLink(
                    atPath: movedItem.path,
                    withDestinationPath: replacedDestinationLinkTarget
                )
            }
            if let error = error as? LinksmithError {
                throw error
            }
            throw LinksmithError.unableToMoveItem(source, movedItem, error.localizedDescription)
        }

        let originalParent = source.deletingLastPathComponent()
        let target = targetPath(for: movedItem, linkIn: originalParent, kind: kind)
        do {
            try fileManager.createSymbolicLink(atPath: source.path, withDestinationPath: target)
        } catch {
            try? moveFile(at: movedItem, to: source)
            throw LinksmithError.unableToCreateLink(source, error.localizedDescription)
        }

        return ReplacedItemSymlink(original: source, movedItem: movedItem, targetPath: target)
    }
}
