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

            let result = SymlinkService().availableLinkURL(for: source, in: destination)
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

            let result = SymlinkService().availableLinkURL(for: source, in: destination)
            #expect(result.lastPathComponent == "report 2.pdf")
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

    private func withTemporaryDirectory(_ body: (URL) throws -> Void) throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: url) }
        try body(url)
    }
}
