import Foundation
import Testing
@testable import LinksmithCore

struct SymlinkServiceTests {
    @Test func generatesRelativeAndAbsoluteTargets() throws {
        let service = SymlinkService()
        let source = URL(fileURLWithPath: "/Users/test/Documents/source.txt")
        let destination = URL(fileURLWithPath: "/Users/test/Desktop/Links", isDirectory: true)

        #expect(service.targetPath(for: source, linkIn: destination, kind: .relative) == "../../Documents/source.txt")
        #expect(service.targetPath(for: source, linkIn: destination, kind: .absolute) == source.path)
    }

    @Test func collisionAddsIncrementingSuffixBeforeExtension() throws {
        try withTemporaryDirectory { root in
            let source = root.appendingPathComponent("source/report.pdf")
            let destination = root.appendingPathComponent("links", isDirectory: true)
            try FileManager.default.createDirectory(at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try Data().write(to: source)
            try Data().write(to: destination.appendingPathComponent("report.pdf"))
            try Data().write(to: destination.appendingPathComponent("report 2.pdf"))

            let result = try SymlinkService().availableLinkURL(for: source, in: destination)
            #expect(result.lastPathComponent == "report 3.pdf")
        }
    }

    @Test func collisionTreatsBrokenSymlinkAsOccupied() throws {
        try withTemporaryDirectory { root in
            let source = root.appendingPathComponent("source/report.pdf")
            let destination = root.appendingPathComponent("links", isDirectory: true)
            try FileManager.default.createDirectory(at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try Data().write(to: source)
            try FileManager.default.createSymbolicLink(
                atPath: destination.appendingPathComponent("report.pdf").path,
                withDestinationPath: "missing.pdf"
            )

            let result = try SymlinkService().availableLinkURL(for: source, in: destination)
            #expect(result.lastPathComponent == "report 2.pdf")
        }
    }

    @Test func createLinksRejectsExistingSymlinkPointingToSameSourceByDefault() throws {
        try withTemporaryDirectory { root in
            let source = root.appendingPathComponent("source/report.pdf")
            let destination = root.appendingPathComponent("links", isDirectory: true)
            let existingLink = destination.appendingPathComponent("report.pdf")
            try FileManager.default.createDirectory(at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try Data("source".utf8).write(to: source)
            try FileManager.default.createSymbolicLink(atPath: existingLink.path, withDestinationPath: source.path)

            #expect(throws: LinksmithError.destinationContainsLinkToSource(source, existingLink)) {
                try SymlinkService().createLinks(to: [source], in: destination, allowsDuplicateTargetLinks: false)
            }
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: existingLink.path) == source.path)
        }
    }

    @Test func createLinksChecksIncrementedCandidatesForSymlinkPointingToSameSource() throws {
        try withTemporaryDirectory { root in
            let source = root.appendingPathComponent("source/report.pdf")
            let destination = root.appendingPathComponent("links", isDirectory: true)
            let existingLink = destination.appendingPathComponent("report 2.pdf")
            try FileManager.default.createDirectory(at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try Data("source".utf8).write(to: source)
            try Data("existing".utf8).write(to: destination.appendingPathComponent("report.pdf"))
            try FileManager.default.createSymbolicLink(atPath: existingLink.path, withDestinationPath: "../source/report.pdf")

            #expect(throws: LinksmithError.destinationContainsLinkToSource(source, existingLink)) {
                try SymlinkService().createLinks(to: [source], in: destination, allowsDuplicateTargetLinks: false)
            }
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: existingLink.path) == "../source/report.pdf")
        }
    }

    @Test func createLinksCanContinueWhenExistingSymlinkPointsToSameSource() throws {
        try withTemporaryDirectory { root in
            let source = root.appendingPathComponent("source/report.pdf")
            let destination = root.appendingPathComponent("links", isDirectory: true)
            try FileManager.default.createDirectory(at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try Data("source".utf8).write(to: source)
            try FileManager.default.createSymbolicLink(
                atPath: destination.appendingPathComponent("report.pdf").path,
                withDestinationPath: source.path
            )

            let created = try SymlinkService().createLinks(to: [source], in: destination)

            #expect(created[0].link.lastPathComponent == "report 2.pdf")
        }
    }

    @Test func createsLinksForMultipleSelections() throws {
        try withTemporaryDirectory { root in
            let sources = ["one.txt", "two.txt"].map { root.appendingPathComponent("sources/\($0)") }
            let destination = root.appendingPathComponent("links", isDirectory: true)
            try FileManager.default.createDirectory(at: sources[0].deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            for source in sources { try Data(source.lastPathComponent.utf8).write(to: source) }

            let created = try SymlinkService().createLinks(to: sources, in: destination)
            #expect(created.count == 2)
            #expect(Set(created.map { $0.link.lastPathComponent }) == Set(["one.txt", "two.txt"]))
            for item in created {
                #expect(try FileManager.default.destinationOfSymbolicLink(atPath: item.link.path) == item.targetPath)
            }
        }
    }

    @Test func createLinksHonorsRelativeAndAbsoluteKinds() throws {
        try withTemporaryDirectory { root in
            let source = root.appendingPathComponent("source.txt")
            let relativeDestination = root.appendingPathComponent("relative", isDirectory: true)
            let absoluteDestination = root.appendingPathComponent("absolute", isDirectory: true)
            try Data().write(to: source)
            try FileManager.default.createDirectory(at: relativeDestination, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: absoluteDestination, withIntermediateDirectories: true)

            let service = SymlinkService()
            let relative = try service.createLinks(to: [source], in: relativeDestination, kind: .relative)[0]
            let absolute = try service.createLinks(to: [source], in: absoluteDestination, kind: .absolute)[0]
            #expect(relative.targetPath == "../source.txt")
            #expect(absolute.targetPath == source.path)
        }
    }

    @Test func createLinksUsesAbsoluteTargetWhenLinksmithMarkerIsOnSourcePathToCommonAncestor() throws {
        try withTemporaryDirectory { root in
            let sourceDirectory = root.appendingPathComponent("project/source", isDirectory: true)
            let source = sourceDirectory.appendingPathComponent("report.txt")
            let destination = root.appendingPathComponent("links", isDirectory: true)
            try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try Data().write(to: source)
            try Data().write(to: root.appendingPathComponent("project/.linksmith"))

            let created = try SymlinkService().createLinks(to: [source], in: destination, kind: .relative)[0]

            #expect(created.targetPath == source.path)
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: created.link.path) == source.path)
        }
    }

    @Test func createLinksUsesAbsoluteTargetWhenLinksmithMarkerIsOnDestinationPathToCommonAncestor() throws {
        try withTemporaryDirectory { root in
            let source = root.appendingPathComponent("source/report.txt")
            let destination = root.appendingPathComponent("project/links", isDirectory: true)
            try FileManager.default.createDirectory(at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try Data().write(to: source)
            try Data().write(to: root.appendingPathComponent("project/.linksmith"))

            let created = try SymlinkService().createLinks(to: [source], in: destination, kind: .relative)[0]

            #expect(created.targetPath == source.path)
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: created.link.path) == source.path)
        }
    }

    @Test func createLinksKeepsRelativeTargetWhenLinksmithMarkerIsAtCommonAncestor() throws {
        try withTemporaryDirectory { root in
            let source = root.appendingPathComponent("source/report.txt")
            let destination = root.appendingPathComponent("links", isDirectory: true)
            try FileManager.default.createDirectory(at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try Data().write(to: source)
            try Data().write(to: root.appendingPathComponent(".linksmith"))

            let created = try SymlinkService().createLinks(to: [source], in: destination, kind: .relative)[0]

            #expect(created.targetPath == "../source/report.txt")
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: created.link.path) == "../source/report.txt")
        }
    }

    @Test func moveItemAndReplaceWithLinkMovesFileAndCreatesRelativeSymlinkAtOriginalPath() throws {
        try withTemporaryDirectory { root in
            let source = root.appendingPathComponent("source/report.txt")
            let destination = root.appendingPathComponent("moved", isDirectory: true)
            try FileManager.default.createDirectory(at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try Data("contents".utf8).write(to: source)

            let replaced = try SymlinkService().moveItemAndReplaceWithLink(source: source, in: destination)
            let linkTarget = try FileManager.default.destinationOfSymbolicLink(atPath: source.path)

            #expect(replaced.original == source)
            #expect(replaced.movedItem == destination.appendingPathComponent("report.txt"))
            #expect(replaced.targetPath == "../moved/report.txt")
            #expect(linkTarget == "../moved/report.txt")
            #expect(try Data(contentsOf: replaced.movedItem) == Data("contents".utf8))
        }
    }

    @Test func moveItemAndReplaceWithLinkRejectsDestinationNameCollisions() throws {
        try withTemporaryDirectory { root in
            let source = root.appendingPathComponent("source/report.txt")
            let destination = root.appendingPathComponent("moved", isDirectory: true)
            let existing = destination.appendingPathComponent("report.txt")
            try FileManager.default.createDirectory(at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try Data("source".utf8).write(to: source)
            try Data("existing".utf8).write(to: existing)

            #expect(throws: LinksmithError.destinationAlreadyContainsItemNamed(existing)) {
                try SymlinkService().moveItemAndReplaceWithLink(source: source, in: destination)
            }
            #expect(try Data(contentsOf: source) == Data("source".utf8))
            #expect(try Data(contentsOf: existing) == Data("existing".utf8))
        }
    }

    @Test func moveItemAndReplaceWithLinkRejectsDestinationFolderNameCollisions() throws {
        try withTemporaryDirectory { root in
            let source = root.appendingPathComponent("source/report.txt")
            let destination = root.appendingPathComponent("moved", isDirectory: true)
            let existing = destination.appendingPathComponent("report.txt", isDirectory: true)
            try FileManager.default.createDirectory(at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: existing, withIntermediateDirectories: true)
            try Data("source".utf8).write(to: source)

            #expect(throws: LinksmithError.destinationAlreadyContainsItemNamed(existing)) {
                try SymlinkService().moveItemAndReplaceWithLink(source: source, in: destination)
            }
            #expect(try Data(contentsOf: source) == Data("source".utf8))
            #expect(FileManager.default.fileExists(atPath: existing.path))
        }
    }

    @Test func moveItemAndReplaceWithLinkRejectsDestinationBrokenSymlinkNameCollisions() throws {
        try withTemporaryDirectory { root in
            let source = root.appendingPathComponent("source/report.txt")
            let destination = root.appendingPathComponent("moved", isDirectory: true)
            let existingLink = destination.appendingPathComponent("report.txt")
            try FileManager.default.createDirectory(at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try Data("source".utf8).write(to: source)
            try FileManager.default.createSymbolicLink(atPath: existingLink.path, withDestinationPath: "missing.txt")

            #expect(throws: LinksmithError.destinationAlreadyContainsItemNamed(existingLink)) {
                try SymlinkService().moveItemAndReplaceWithLink(source: source, in: destination)
            }
            #expect(try Data(contentsOf: source) == Data("source".utf8))
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: existingLink.path) == "missing.txt")
        }
    }

    @Test func moveItemAndReplaceWithLinkRejectsDestinationSymlinkPointingToSourceByDefault() throws {
        try withTemporaryDirectory { root in
            let source = root.appendingPathComponent("source/report.txt")
            let destination = root.appendingPathComponent("moved", isDirectory: true)
            let existingLink = destination.appendingPathComponent("report.txt")
            try FileManager.default.createDirectory(at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try Data("source".utf8).write(to: source)
            try FileManager.default.createSymbolicLink(atPath: existingLink.path, withDestinationPath: source.path)

            #expect(throws: LinksmithError.destinationContainsLinkToSource(source, existingLink)) {
                try SymlinkService().moveItemAndReplaceWithLink(source: source, in: destination)
            }
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: existingLink.path) == source.path)
            #expect(try Data(contentsOf: source) == Data("source".utf8))
        }
    }

    @Test func moveItemAndReplaceWithLinkDetectsRelativeDestinationSymlinkPointingToSource() throws {
        try withTemporaryDirectory { root in
            let source = root.appendingPathComponent("source/report.txt")
            let destination = root.appendingPathComponent("moved", isDirectory: true)
            let existingLink = destination.appendingPathComponent("report.txt")
            try FileManager.default.createDirectory(at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try Data("source".utf8).write(to: source)
            try FileManager.default.createSymbolicLink(atPath: existingLink.path, withDestinationPath: "../source/report.txt")

            #expect(throws: LinksmithError.destinationContainsLinkToSource(source, existingLink)) {
                try SymlinkService().moveItemAndReplaceWithLink(source: source, in: destination)
            }
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: existingLink.path) == "../source/report.txt")
            #expect(try Data(contentsOf: source) == Data("source".utf8))
        }
    }

    @Test func moveItemAndReplaceWithLinkCanReplaceDestinationSymlinkPointingToSource() throws {
        try withTemporaryDirectory { root in
            let source = root.appendingPathComponent("source/report.txt")
            let destination = root.appendingPathComponent("moved", isDirectory: true)
            let existingLink = destination.appendingPathComponent("report.txt")
            try FileManager.default.createDirectory(at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try Data("source".utf8).write(to: source)
            try FileManager.default.createSymbolicLink(atPath: existingLink.path, withDestinationPath: source.path)

            let replaced = try SymlinkService().moveItemAndReplaceWithLink(
                source: source,
                in: destination,
                replacesExistingDestinationSymlink: true
            )

            #expect(replaced.movedItem == existingLink)
            #expect(try Data(contentsOf: existingLink) == Data("source".utf8))
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: source.path) == "../moved/report.txt")
        }
    }

    @Test func moveItemAndReplaceWithLinkCanReplaceRelativeDestinationSymlinkPointingToSource() throws {
        try withTemporaryDirectory { root in
            let source = root.appendingPathComponent("source/report.txt")
            let destination = root.appendingPathComponent("moved", isDirectory: true)
            let existingLink = destination.appendingPathComponent("report.txt")
            try FileManager.default.createDirectory(at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try Data("source".utf8).write(to: source)
            try FileManager.default.createSymbolicLink(atPath: existingLink.path, withDestinationPath: "../source/report.txt")

            let replaced = try SymlinkService().moveItemAndReplaceWithLink(
                source: source,
                in: destination,
                replacesExistingDestinationSymlink: true
            )

            #expect(replaced.movedItem == existingLink)
            #expect(try Data(contentsOf: existingLink) == Data("source".utf8))
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: source.path) == "../moved/report.txt")
        }
    }

    @Test func moveItemAndReplaceWithLinkRejectsDestinationSymlinkPointingElsewhere() throws {
        try withTemporaryDirectory { root in
            let source = root.appendingPathComponent("source/report.txt")
            let destination = root.appendingPathComponent("moved", isDirectory: true)
            let other = root.appendingPathComponent("other/report.txt")
            let existingLink = destination.appendingPathComponent("report.txt")
            try FileManager.default.createDirectory(at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: other.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("source".utf8).write(to: source)
            try Data("other".utf8).write(to: other)
            try FileManager.default.createSymbolicLink(atPath: existingLink.path, withDestinationPath: other.path)

            #expect(throws: LinksmithError.destinationAlreadyContainsItemNamed(existingLink)) {
                try SymlinkService().moveItemAndReplaceWithLink(source: source, in: destination)
            }
            #expect(try Data(contentsOf: source) == Data("source".utf8))
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: existingLink.path) == other.path)
        }
    }

    @Test func moveItemAndReplaceWithLinkRejectsSourceAlreadyLinkedIntoDestination() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("moved", isDirectory: true)
            let target = destination.appendingPathComponent("report.txt")
            let source = root.appendingPathComponent("source/report.txt")
            try FileManager.default.createDirectory(at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try Data("target".utf8).write(to: target)
            try FileManager.default.createSymbolicLink(atPath: source.path, withDestinationPath: target.path)

            #expect(throws: LinksmithError.sourceAlreadyLinksToDestination(source, target)) {
                try SymlinkService().moveItemAndReplaceWithLink(source: source, in: destination)
            }
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: source.path) == target.path)
            #expect(try Data(contentsOf: target) == Data("target".utf8))
        }
    }

    @Test func moveItemAndReplaceWithLinkRejectsMissingSource() throws {
        try withTemporaryDirectory { root in
            let source = root.appendingPathComponent("missing.txt")
            let destination = root.appendingPathComponent("moved", isDirectory: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

            #expect(throws: LinksmithError.sourceDoesNotExist(source)) {
                try SymlinkService().moveItemAndReplaceWithLink(source: source, in: destination)
            }
        }
    }

    @Test func moveItemAndReplaceWithLinkRejectsFileDestination() throws {
        try withTemporaryDirectory { root in
            let source = root.appendingPathComponent("source.txt")
            let destination = root.appendingPathComponent("destination.txt")
            try Data("source".utf8).write(to: source)
            try Data("destination".utf8).write(to: destination)

            #expect(throws: LinksmithError.destinationIsNotDirectory(destination)) {
                try SymlinkService().moveItemAndReplaceWithLink(source: source, in: destination)
            }
            #expect(try Data(contentsOf: source) == Data("source".utf8))
            #expect(try Data(contentsOf: destination) == Data("destination".utf8))
        }
    }

    @Test func moveItemAndReplaceWithLinkHonorsAbsoluteKind() throws {
        try withTemporaryDirectory { root in
            let source = root.appendingPathComponent("source.txt")
            let destination = root.appendingPathComponent("moved", isDirectory: true)
            try Data().write(to: source)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

            let replaced = try SymlinkService().moveItemAndReplaceWithLink(
                source: source,
                in: destination,
                kind: .absolute
            )

            #expect(replaced.targetPath == replaced.movedItem.path)
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: source.path) == replaced.movedItem.path)
        }
    }

    @Test func moveItemAndReplaceWithLinkUsesAbsoluteTargetWhenLinksmithMarkerIsOnMovedPathToCommonAncestor() throws {
        try withTemporaryDirectory { root in
            let source = root.appendingPathComponent("source/report.txt")
            let destination = root.appendingPathComponent("project/moved", isDirectory: true)
            try FileManager.default.createDirectory(at: source.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
            try Data("contents".utf8).write(to: source)
            try Data().write(to: root.appendingPathComponent("project/.linksmith"))

            let replaced = try SymlinkService().moveItemAndReplaceWithLink(source: source, in: destination)

            #expect(replaced.targetPath == replaced.movedItem.path)
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: source.path) == replaced.movedItem.path)
        }
    }

    @Test func moveItemAndReplaceWithLinkRejectsFolderSource() throws {
        try withTemporaryDirectory { root in
            let source = root.appendingPathComponent("source", isDirectory: true)
            let destination = root.appendingPathComponent("moved", isDirectory: true)
            try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

            #expect(throws: LinksmithError.sourceMustBeFile(source)) {
                try SymlinkService().moveItemAndReplaceWithLink(source: source, in: destination)
            }
        }
    }

    @Test func symbolicLinkTargetPathDetectsBrokenSymlinks() throws {
        try withTemporaryDirectory { root in
            let link = root.appendingPathComponent("broken-link.txt")
            try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "missing.txt")

            #expect(SymlinkService().symbolicLinkTargetPath(at: link) == "missing.txt")
        }
    }

    @Test func symlinkReplacementAuthorizationUsesCommonAncestorWhenNoMarkerBoundaryIsCrossed() throws {
        try withTemporaryDirectory { root in
            let target = root.appendingPathComponent("target/report.txt")
            let link = root.appendingPathComponent("link/report.txt")
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: target)
            try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "../target/report.txt")

            let directories = try SymlinkService().authorizationDirectoriesForReplacingSymlink(at: link)

            #expect(directories == [root.standardizedFileURL])
        }
    }

    @Test func symlinkReplacementAuthorizationUsesSeparateFoldersWhenMarkerBoundaryWouldBeCrossed() throws {
        try withTemporaryDirectory { root in
            let target = root.appendingPathComponent("target/report.txt")
            let link = root.appendingPathComponent("project/link/report.txt")
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: target)
            try Data().write(to: root.appendingPathComponent("project/.linksmith"))
            try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "../../target/report.txt")

            let directories = try SymlinkService().authorizationDirectoriesForReplacingSymlink(at: link)

            #expect(directories == [
                link.deletingLastPathComponent().standardizedFileURL,
                target.deletingLastPathComponent().standardizedFileURL,
            ])
        }
    }

    @Test func symlinkReplacementAuthorizationUsesCommonAncestorWhenMarkerIsAtCommonAncestor() throws {
        try withTemporaryDirectory { root in
            let target = root.appendingPathComponent("target/report.txt")
            let link = root.appendingPathComponent("link/report.txt")
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: target)
            try Data().write(to: root.appendingPathComponent(".linksmith"))
            try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "../target/report.txt")

            let directories = try SymlinkService().authorizationDirectoriesForReplacingSymlink(at: link)

            #expect(directories == [root.standardizedFileURL])
        }
    }

    @Test func symlinkReplacementAuthorizationDoesNotAskForHomeWhenTopLevelUserFoldersDiffer() throws {
        try withTemporaryDirectory { root in
            let home = root.appendingPathComponent("Users/test", isDirectory: true)
            let target = home.appendingPathComponent("Pictures/report.txt")
            let link = home.appendingPathComponent("Documents/report.txt")
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: target)
            try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "../Pictures/report.txt")

            let directories = try SymlinkService(
                homeDirectoryForAuthorization: home
            ).authorizationDirectoriesForReplacingSymlink(at: link)

            #expect(directories == [
                home.appendingPathComponent("Documents", isDirectory: true).standardizedFileURL,
                home.appendingPathComponent("Pictures", isDirectory: true).standardizedFileURL,
            ])
        }
    }

    @Test func symlinkReplacementAuthorizationCanAskForSharedTopLevelUserFolder() throws {
        try withTemporaryDirectory { root in
            let home = root.appendingPathComponent("Users/test", isDirectory: true)
            let target = home.appendingPathComponent("Desktop/target/report.txt")
            let link = home.appendingPathComponent("Desktop/link/report.txt")
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: target)
            try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "../target/report.txt")

            let directories = try SymlinkService(
                homeDirectoryForAuthorization: home
            ).authorizationDirectoriesForReplacingSymlink(at: link)

            #expect(directories == [home.appendingPathComponent("Desktop", isDirectory: true).standardizedFileURL])
        }
    }

    @Test func symlinkReplacementAuthorizationSupportsBrokenSymlinks() throws {
        try withTemporaryDirectory { root in
            let link = root.appendingPathComponent("link/report.txt")
            try FileManager.default.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "../missing/report.txt")

            let directories = try SymlinkService().authorizationDirectoriesForReplacingSymlink(at: link)

            #expect(directories == [root.standardizedFileURL])
        }
    }

    @Test func copyTargetReplacingSymlinkCopiesTargetAndLeavesOriginal() throws {
        try withTemporaryDirectory { root in
            let target = root.appendingPathComponent("target/report.txt")
            let link = root.appendingPathComponent("link/report.txt")
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("contents".utf8).write(to: target)
            try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "../target/report.txt")

            let replaced = try SymlinkService().copyTargetReplacingSymlink(at: link)

            #expect(replaced.symbolicLink == link)
            #expect(replaced.originalTargetPath == "../target/report.txt")
            #expect(replaced.resolvedTarget == target)
            #expect(try Data(contentsOf: link) == Data("contents".utf8))
            #expect(try Data(contentsOf: target) == Data("contents".utf8))
            #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: link.path)) == nil)
        }
    }

    @Test func moveTargetReplacingSymlinkMovesTargetAndRemovesOriginal() throws {
        try withTemporaryDirectory { root in
            let target = root.appendingPathComponent("target/report.txt")
            let link = root.appendingPathComponent("link/report.txt")
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("contents".utf8).write(to: target)
            try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: target.path)

            let replaced = try SymlinkService().moveTargetReplacingSymlink(at: link)

            #expect(replaced.symbolicLink == link)
            #expect(replaced.originalTargetPath == target.path)
            #expect(replaced.resolvedTarget == target)
            #expect(try Data(contentsOf: link) == Data("contents".utf8))
            #expect(FileManager.default.fileExists(atPath: target.path) == false)
            #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: link.path)) == nil)
        }
    }

    @Test func swapTargetWithSymlinkMovesTargetAndCreatesReplacementLink() throws {
        try withTemporaryDirectory { root in
            let target = root.appendingPathComponent("target/report.txt")
            let link = root.appendingPathComponent("link/report.txt")
            try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data("contents".utf8).write(to: target)
            try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "../target/report.txt")

            let swapped = try SymlinkService().swapTargetWithSymlink(at: link)

            #expect(swapped.originalSymbolicLink == link)
            #expect(swapped.movedItem == link)
            #expect(swapped.replacementSymbolicLink == target)
            #expect(swapped.replacementTargetPath == "../link/report.txt")
            #expect(try Data(contentsOf: link) == Data("contents".utf8))
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: target.path) == "../link/report.txt")
        }
    }

    @Test func symlinkTargetReplacementRejectsBrokenSymlinkWithoutRemovingIt() throws {
        try withTemporaryDirectory { root in
            let link = root.appendingPathComponent("broken-link.txt")
            try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "missing.txt")

            #expect(throws: LinksmithError.symbolicLinkTargetDoesNotExist(link, "missing.txt")) {
                try SymlinkService().copyTargetReplacingSymlink(at: link)
            }
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: link.path) == "missing.txt")
        }
    }

    @Test func createLinksRejectsEmptySources() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("links", isDirectory: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

            #expect(throws: LinksmithError.noSources) {
                try SymlinkService().createLinks(to: [], in: destination)
            }
        }
    }

    @Test func createLinksRejectsMissingSource() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("links", isDirectory: true)
            let source = root.appendingPathComponent("missing.txt")
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

            #expect(throws: LinksmithError.sourceDoesNotExist(source)) {
                try SymlinkService().createLinks(to: [source], in: destination)
            }
        }
    }

    @Test func createLinksCanAllowUnresolvedSources() throws {
        try withTemporaryDirectory { root in
            let destination = root.appendingPathComponent("links", isDirectory: true)
            let source = root.appendingPathComponent("missing.txt")
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

            let created = try SymlinkService().createLinks(
                to: [source],
                in: destination,
                sourceValidation: .allowUnresolvedSources
            )

            #expect(created.map(\.source) == [source])
            #expect(try FileManager.default.destinationOfSymbolicLink(atPath: created[0].link.path) == "../missing.txt")
        }
    }

    @Test func createLinksRejectsFileDestination() throws {
        try withTemporaryDirectory { root in
            let source = root.appendingPathComponent("source.txt")
            let destination = root.appendingPathComponent("destination.txt")
            try Data().write(to: source)
            try Data().write(to: destination)

            #expect(throws: LinksmithError.destinationIsNotDirectory(destination)) {
                try SymlinkService().createLinks(to: [source], in: destination)
            }
        }
    }
}
