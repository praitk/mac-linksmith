import Foundation
import Testing
@testable import LinksmithCore

struct LinksmithErrorTests {
    @Test func noSourcesDescriptionIsClear() {
        #expect(LinksmithError.noSources.errorDescription == "No files or folders were selected.")
    }

    @Test func missingSourceDescriptionMentionsPath() {
        let error = LinksmithError.sourceDoesNotExist(URL(fileURLWithPath: "/tmp/missing.pdf"))

        #expect(error.errorDescription == "The selected item no longer exists: /tmp/missing.pdf")
    }

    @Test func sourceMustBeFileDescriptionMentionsPath() {
        let error = LinksmithError.sourceMustBeFile(URL(fileURLWithPath: "/tmp/folder"))

        #expect(error.errorDescription == "The selected item must be a file: /tmp/folder")
    }

    @Test func sourceAlreadyLinkedDescriptionMentionsTarget() {
        let source = URL(fileURLWithPath: "/tmp/source/report.pdf")
        let target = URL(fileURLWithPath: "/tmp/links/report.pdf")

        let error = LinksmithError.sourceAlreadyLinksToDestination(source, target)

        #expect(error.errorDescription == "report.pdf is already a symbolic link to /tmp/links/report.pdf.")
    }

    @Test func destinationNameCollisionDescriptionMentionsConflictingItemName() {
        let error = LinksmithError.destinationAlreadyContainsItemNamed(
            URL(fileURLWithPath: "/tmp/links/report.pdf")
        )

        #expect(error.errorDescription == "The destination already contains another item named report.pdf.")
    }

    @Test func destinationLinkToSourceDescriptionMentionsSourcePath() {
        let source = URL(fileURLWithPath: "/tmp/source/report.pdf")
        let link = URL(fileURLWithPath: "/tmp/links/report.pdf")

        let error = LinksmithError.destinationContainsLinkToSource(source, link)

        #expect(error.errorDescription == "report.pdf in the destination is already a symbolic link to /tmp/source/report.pdf.")
    }

    @Test func replaceDestinationLinkFailureDescriptionNamesLink() {
        let error = LinksmithError.unableToReplaceDestinationLink(
            URL(fileURLWithPath: "/tmp/links/report.pdf"),
            "Operation not permitted"
        )

        #expect(error.errorDescription == "Could not replace the existing symbolic link report.pdf: Operation not permitted")
    }

    @Test func moveFailureDescriptionAvoidsDuplicatingUnderlyingMessage() {
        let source = URL(fileURLWithPath: "/tmp/source/report.pdf")
        let destination = URL(fileURLWithPath: "/tmp/links/report.pdf")

        let error = LinksmithError.unableToMoveItem(source, destination, "Operation not permitted")

        #expect(error.errorDescription == "Could not move report.pdf to /tmp/links: Operation not permitted")
    }

    @Test func fileDestinationDescriptionMentionsPath() {
        let error = LinksmithError.destinationIsNotDirectory(URL(fileURLWithPath: "/tmp/file.txt"))

        #expect(error.errorDescription == "The selected destination is not a folder: /tmp/file.txt")
    }

    @Test func nonSymlinkDescriptionMentionsPath() {
        let error = LinksmithError.selectedItemIsNotSymbolicLink(URL(fileURLWithPath: "/tmp/report.pdf"))

        #expect(error.errorDescription == "The selected item is not a symbolic link: /tmp/report.pdf")
    }

    @Test func brokenSymlinkDescriptionMentionsTargetPath() {
        let error = LinksmithError.symbolicLinkTargetDoesNotExist(
            URL(fileURLWithPath: "/tmp/link.pdf"),
            "../missing.pdf"
        )

        #expect(error.errorDescription == "link.pdf points to a target that no longer exists: ../missing.pdf")
    }

    @Test func copyFailureDescriptionAvoidsDuplicatingUnderlyingMessage() {
        let source = URL(fileURLWithPath: "/tmp/source/report.pdf")
        let destination = URL(fileURLWithPath: "/tmp/link/report.pdf")

        let error = LinksmithError.unableToCopyItem(source, destination, "Operation not permitted")

        #expect(error.errorDescription == "Could not copy report.pdf to /tmp/link: Operation not permitted")
    }

    @Test func createLinkFailureDescriptionNamesLink() {
        let error = LinksmithError.unableToCreateLink(
            URL(fileURLWithPath: "/tmp/links/report.pdf"),
            "Operation not permitted"
        )

        #expect(error.errorDescription == "Could not create report.pdf: Operation not permitted")
    }
}
