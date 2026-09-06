import Darwin
import Foundation

public enum SymlinkKind: String, Codable, Sendable {
    case relative
    case absolute
}

public enum SourceValidationPolicy: Sendable {
    case requireExistingSources
    case allowUnresolvedSources
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

public struct LinkCreationPlan: Equatable, Sendable {
    public let items: [LinkCreationPlanItem]

    public init(items: [LinkCreationPlanItem]) {
        self.items = items
    }
}

public struct LinkCreationPlanItem: Equatable, Sendable {
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

public struct ReplacedSymlinkTarget: Equatable, Sendable {
    public let symbolicLink: URL
    public let originalTargetPath: String
    public let resolvedTarget: URL

    public init(symbolicLink: URL, originalTargetPath: String, resolvedTarget: URL) {
        self.symbolicLink = symbolicLink
        self.originalTargetPath = originalTargetPath
        self.resolvedTarget = resolvedTarget
    }
}

public struct SwappedSymlinkTarget: Equatable, Sendable {
    public let originalSymbolicLink: URL
    public let movedItem: URL
    public let replacementSymbolicLink: URL
    public let replacementTargetPath: String

    public init(
        originalSymbolicLink: URL,
        movedItem: URL,
        replacementSymbolicLink: URL,
        replacementTargetPath: String
    ) {
        self.originalSymbolicLink = originalSymbolicLink
        self.movedItem = movedItem
        self.replacementSymbolicLink = replacementSymbolicLink
        self.replacementTargetPath = replacementTargetPath
    }
}

public struct SymlinkService {
    private static let markerFileName = ".linksmith"

    private let fileManager: FileManager
    private let homeDirectoryForAuthorization: URL

    public init(
        fileManager: FileManager = .default,
        homeDirectoryForAuthorization: URL = FileManager.default.homeDirectoryForCurrentUser
    ) {
        self.fileManager = fileManager
        self.homeDirectoryForAuthorization = homeDirectoryForAuthorization.standardizedFileURL
    }

    public func targetPath(for source: URL, linkIn destination: URL, kind: SymlinkKind) -> String {
        let source = source.standardizedFileURL
        let destination = destination.standardizedFileURL
        guard kind == .relative,
              hasMarkerBelowCommonAncestor(
                firstDirectory: directoryForMarkerSearch(from: source),
                secondDirectory: destination
              ) == false else {
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

    private func hasMarkerBelowCommonAncestor(firstDirectory: URL, secondDirectory: URL) -> Bool {
        let firstComponents = firstDirectory.standardizedFileURL.pathComponents
        let secondComponents = secondDirectory.standardizedFileURL.pathComponents
        let sharedCount = commonAncestorComponentCount(firstComponents, secondComponents)

        guard sharedCount > 0 else { return false }

        return pathBelowCommonAncestorContainsMarker(
            components: firstComponents,
            from: firstComponents.count,
            above: sharedCount
        ) || pathBelowCommonAncestorContainsMarker(
            components: secondComponents,
            from: secondComponents.count,
            above: sharedCount
        )
    }

    private func commonAncestorComponentCount(_ first: [String], _ second: [String]) -> Int {
        var sharedCount = 0

        while sharedCount < min(first.count, second.count),
              first[sharedCount] == second[sharedCount] {
            sharedCount += 1
        }

        return sharedCount
    }

    private func commonAncestorDirectory(_ first: URL, _ second: URL) -> URL {
        let firstComponents = first.standardizedFileURL.pathComponents
        let secondComponents = second.standardizedFileURL.pathComponents
        let sharedCount = commonAncestorComponentCount(firstComponents, secondComponents)
        return URL(fileURLWithPath: NSString.path(withComponents: Array(firstComponents.prefix(sharedCount))), isDirectory: true)
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

    public func availableLinkURL(
        for source: URL,
        in destination: URL,
        allowsDuplicateTargetLink: Bool = true
    ) throws -> URL {
        var reservedPaths = Set<String>()
        return try availableLinkURL(
            for: source,
            in: destination,
            allowsDuplicateTargetLink: allowsDuplicateTargetLink,
            reservedPaths: &reservedPaths
        )
    }

    private func availableLinkURL(
        for source: URL,
        in destination: URL,
        allowsDuplicateTargetLink: Bool,
        reservedPaths: inout Set<String>
    ) throws -> URL {
        var candidate = destination.appendingPathComponent(source.lastPathComponent)
        if try isLinkPathAvailable(
            candidate,
            for: source,
            allowsDuplicateTargetLink: allowsDuplicateTargetLink,
            reservedPaths: reservedPaths
        ) {
            reservedPaths.insert(candidate.standardizedFileURL.path)
            return candidate
        }

        let name = source.deletingPathExtension().lastPathComponent
        let pathExtension = source.pathExtension
        var suffix = 2

        while true {
            let candidateName = pathExtension.isEmpty
                ? "\(name) \(suffix)"
                : "\(name) \(suffix).\(pathExtension)"
            candidate = destination.appendingPathComponent(candidateName)
            if try isLinkPathAvailable(
                candidate,
                for: source,
                allowsDuplicateTargetLink: allowsDuplicateTargetLink,
                reservedPaths: reservedPaths
            ) {
                reservedPaths.insert(candidate.standardizedFileURL.path)
                return candidate
            }
            suffix += 1
        }
    }

    private func isLinkPathAvailable(
        _ url: URL,
        for source: URL,
        allowsDuplicateTargetLink: Bool
    ) throws -> Bool {
        try isLinkPathAvailable(
            url,
            for: source,
            allowsDuplicateTargetLink: allowsDuplicateTargetLink,
            reservedPaths: []
        )
    }

    private func isLinkPathAvailable(
        _ url: URL,
        for source: URL,
        allowsDuplicateTargetLink: Bool,
        reservedPaths: Set<String>
    ) throws -> Bool {
        if let existingTarget = resolvedSymbolicLinkDestination(at: url),
           refersToSameFile(existingTarget, source),
           allowsDuplicateTargetLink == false {
            throw LinksmithError.destinationContainsLinkToSource(source, url)
        }

        return reservedPaths.contains(url.standardizedFileURL.path) == false && isPathAvailable(url)
    }

    private func isPathAvailable(_ url: URL) -> Bool {
        if fileManager.fileExists(atPath: url.path) {
            return false
        }

        return (try? fileManager.destinationOfSymbolicLink(atPath: url.path)) == nil
    }

    public func symbolicLinkTargetPath(at url: URL) -> String? {
        symbolicLinkTarget(at: url.standardizedFileURL)
    }

    public func authorizationDirectoriesForReplacingSymlink(at link: URL) throws -> [URL] {
        let link = link.standardizedFileURL
        guard let targetPath = symbolicLinkTarget(at: link) else {
            throw LinksmithError.selectedItemIsNotSymbolicLink(link)
        }

        let linkFolder = link.deletingLastPathComponent().standardizedFileURL
        let targetFolder = resolvedSymbolicLinkTarget(targetPath: targetPath, for: link)
            .deletingLastPathComponent()
            .standardizedFileURL

        if hasMarkerBelowCommonAncestor(firstDirectory: linkFolder, secondDirectory: targetFolder) {
            return uniqueStandardizedURLs([linkFolder, targetFolder])
        }

        let commonAncestor = commonAncestorDirectory(linkFolder, targetFolder)
        if let homeBoundedDirectories = homeBoundedAuthorizationDirectories(
            commonAncestor: commonAncestor,
            firstDirectory: linkFolder,
            secondDirectory: targetFolder
        ) {
            return homeBoundedDirectories
        }

        return [commonAncestor]
    }

    private func symbolicLinkTarget(at url: URL) -> String? {
        try? fileManager.destinationOfSymbolicLink(atPath: url.path)
    }

    private func resolvedSymbolicLinkDestination(at url: URL) -> URL? {
        guard let target = symbolicLinkTarget(at: url) else {
            return nil
        }

        return resolvedSymbolicLinkTarget(targetPath: target, for: url)
    }

    private func resolvedSymbolicLinkTarget(targetPath: String, for link: URL) -> URL {
        let link = link.standardizedFileURL
        if targetPath.hasPrefix("/") {
            return URL(fileURLWithPath: targetPath).standardizedFileURL
        }

        return link.deletingLastPathComponent()
            .appendingPathComponent(targetPath)
            .standardizedFileURL
    }

    private func uniqueStandardizedURLs(_ urls: [URL]) -> [URL] {
        var seen: Set<String> = []
        var unique: [URL] = []

        for url in urls.map(\.standardizedFileURL) where seen.insert(url.path).inserted {
            unique.append(url)
        }

        return unique
    }

    private func homeBoundedAuthorizationDirectories(
        commonAncestor: URL,
        firstDirectory: URL,
        secondDirectory: URL
    ) -> [URL]? {
        guard isDescendantOrSame(firstDirectory, of: homeDirectoryForAuthorization),
              isDescendantOrSame(secondDirectory, of: homeDirectoryForAuthorization) else {
            return nil
        }

        let commonComponents = commonAncestor.standardizedFileURL.pathComponents
        let homeComponents = homeDirectoryForAuthorization.pathComponents
        guard commonComponents.starts(with: homeComponents),
              commonComponents.count <= homeComponents.count else {
            return nil
        }

        return uniqueStandardizedURLs([
            topLevelUserFolder(for: firstDirectory),
            topLevelUserFolder(for: secondDirectory),
        ])
    }

    private func isDescendantOrSame(_ url: URL, of ancestor: URL) -> Bool {
        let components = url.standardizedFileURL.pathComponents
        let ancestorComponents = ancestor.standardizedFileURL.pathComponents
        return components.starts(with: ancestorComponents)
    }

    private func topLevelUserFolder(for directory: URL) -> URL {
        let components = directory.standardizedFileURL.pathComponents
        let homeComponents = homeDirectoryForAuthorization.pathComponents
        guard components.starts(with: homeComponents),
              components.count > homeComponents.count else {
            return directory.standardizedFileURL
        }

        return URL(
            fileURLWithPath: NSString.path(withComponents: Array(components.prefix(homeComponents.count + 1))),
            isDirectory: true
        )
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

    private func resolvedRequiredSymbolicLinkTarget(at link: URL) throws -> (targetPath: String, target: URL) {
        let link = link.standardizedFileURL
        guard let targetPath = symbolicLinkTarget(at: link) else {
            throw LinksmithError.selectedItemIsNotSymbolicLink(link)
        }

        let target = resolvedSymbolicLinkTarget(targetPath: targetPath, for: link)

        guard fileManager.fileExists(atPath: target.path) else {
            throw LinksmithError.symbolicLinkTargetDoesNotExist(link, targetPath)
        }

        return (targetPath, target)
    }

    private func restoreSymbolicLink(at link: URL, targetPath: String) {
        try? fileManager.createSymbolicLink(atPath: link.path, withDestinationPath: targetPath)
    }

    @discardableResult
    public func planLinks(
        to sources: [URL],
        in destination: URL,
        kind: SymlinkKind = .relative,
        sourceValidation: SourceValidationPolicy = .requireExistingSources,
        allowsDuplicateTargetLinks: Bool = true
    ) throws -> LinkCreationPlan {
        guard sources.isEmpty == false else { throw LinksmithError.noSources }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: destination.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            throw LinksmithError.destinationIsNotDirectory(destination)
        }

        var reservedPaths = Set<String>()
        let items = try sources.map { source in
            guard sourceValidation == .allowUnresolvedSources || fileManager.fileExists(atPath: source.path) else {
                throw LinksmithError.sourceDoesNotExist(source)
            }

            let link = try availableLinkURL(
                for: source,
                in: destination,
                allowsDuplicateTargetLink: allowsDuplicateTargetLinks,
                reservedPaths: &reservedPaths
            )
            let target = targetPath(for: source, linkIn: destination, kind: kind)
            return LinkCreationPlanItem(source: source, link: link, targetPath: target)
        }

        return LinkCreationPlan(items: items)
    }

    @discardableResult
    public func createLinks(from plan: LinkCreationPlan) throws -> [CreatedSymlink] {
        try plan.items.map { item in
            do {
                try fileManager.createSymbolicLink(atPath: item.link.path, withDestinationPath: item.targetPath)
            } catch {
                throw LinksmithError.unableToCreateLink(item.link, error.localizedDescription)
            }
            return CreatedSymlink(source: item.source, link: item.link, targetPath: item.targetPath)
        }
    }

    @discardableResult
    public func createLinks(
        to sources: [URL],
        in destination: URL,
        kind: SymlinkKind = .relative,
        sourceValidation: SourceValidationPolicy = .requireExistingSources,
        allowsDuplicateTargetLinks: Bool = true
    ) throws -> [CreatedSymlink] {
        let plan = try planLinks(
            to: sources,
            in: destination,
            kind: kind,
            sourceValidation: sourceValidation,
            allowsDuplicateTargetLinks: allowsDuplicateTargetLinks
        )
        return try createLinks(from: plan)
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

    @discardableResult
    public func copyTargetReplacingSymlink(at link: URL) throws -> ReplacedSymlinkTarget {
        let link = link.standardizedFileURL
        let (targetPath, target) = try resolvedRequiredSymbolicLinkTarget(at: link)

        do {
            try removeSymbolicLink(at: link)
        } catch {
            throw error
        }

        do {
            try fileManager.copyItem(at: target, to: link)
        } catch {
            restoreSymbolicLink(at: link, targetPath: targetPath)
            throw LinksmithError.unableToCopyItem(target, link, error.localizedDescription)
        }

        return ReplacedSymlinkTarget(symbolicLink: link, originalTargetPath: targetPath, resolvedTarget: target)
    }

    @discardableResult
    public func moveTargetReplacingSymlink(at link: URL) throws -> ReplacedSymlinkTarget {
        let link = link.standardizedFileURL
        let (targetPath, target) = try resolvedRequiredSymbolicLinkTarget(at: link)

        do {
            try removeSymbolicLink(at: link)
        } catch {
            throw error
        }

        do {
            try moveFile(at: target, to: link)
        } catch {
            restoreSymbolicLink(at: link, targetPath: targetPath)
            if let error = error as? LinksmithError {
                throw error
            }
            throw LinksmithError.unableToMoveItem(target, link, error.localizedDescription)
        }

        return ReplacedSymlinkTarget(symbolicLink: link, originalTargetPath: targetPath, resolvedTarget: target)
    }

    @discardableResult
    public func swapTargetWithSymlink(at link: URL, kind: SymlinkKind = .relative) throws -> SwappedSymlinkTarget {
        let link = link.standardizedFileURL
        let (originalTargetPath, target) = try resolvedRequiredSymbolicLinkTarget(at: link)

        do {
            try removeSymbolicLink(at: link)
        } catch {
            throw error
        }

        do {
            try moveFile(at: target, to: link)
        } catch {
            restoreSymbolicLink(at: link, targetPath: originalTargetPath)
            if let error = error as? LinksmithError {
                throw error
            }
            throw LinksmithError.unableToMoveItem(target, link, error.localizedDescription)
        }

        let replacementTarget = targetPath(for: link, linkIn: target.deletingLastPathComponent(), kind: kind)
        do {
            try fileManager.createSymbolicLink(atPath: target.path, withDestinationPath: replacementTarget)
        } catch {
            try? moveFile(at: link, to: target)
            restoreSymbolicLink(at: link, targetPath: originalTargetPath)
            throw LinksmithError.unableToCreateLink(target, error.localizedDescription)
        }

        return SwappedSymlinkTarget(
            originalSymbolicLink: link,
            movedItem: link,
            replacementSymbolicLink: target,
            replacementTargetPath: replacementTarget
        )
    }
}
