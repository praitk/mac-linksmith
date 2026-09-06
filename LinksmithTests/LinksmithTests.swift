import Foundation
import Testing
import LinksmithCore
@testable import Linksmith

struct LinksmithTests {
    @Test func singleLinkCompletionMentionsActualCreatedLinkName() {
        let created = CreatedSymlink(
            source: URL(fileURLWithPath: "/tmp/source/report.pdf"),
            link: URL(fileURLWithPath: "/tmp/links/report 2.pdf"),
            targetPath: "../source/report.pdf"
        )

        let content = LinkCompletionAlertContent.createdLinks([created])

        #expect(content.message == "Link Created")
        #expect(content.informativeText == "Created symbolic link: report 2.pdf.")
    }

    @Test func multipleLinksCompletionMentionsAllActualCreatedLinkNames() {
        let created = [
            CreatedSymlink(
                source: URL(fileURLWithPath: "/tmp/source/report.pdf"),
                link: URL(fileURLWithPath: "/tmp/links/report 2.pdf"),
                targetPath: "../source/report.pdf"
            ),
            CreatedSymlink(
                source: URL(fileURLWithPath: "/tmp/source/image.png"),
                link: URL(fileURLWithPath: "/tmp/links/image.png"),
                targetPath: "../source/image.png"
            ),
        ]

        let content = LinkCompletionAlertContent.createdLinks(created)

        #expect(content.message == "Links Created")
        #expect(content.informativeText == "Created 2 symbolic links:\nreport 2.pdf\nimage.png")
    }

    @Test func moveAndReplaceCompletionMentionsMovedFileAndCreatedLinkName() {
        let replaced = ReplacedItemSymlink(
            original: URL(fileURLWithPath: "/tmp/source/report.pdf"),
            movedItem: URL(fileURLWithPath: "/tmp/moved/report.pdf"),
            targetPath: "../moved/report.pdf"
        )

        let content = LinkCompletionAlertContent.replacedItem(replaced)

        #expect(content.message == "File Moved")
        #expect(content.informativeText == "Moved report.pdf and created symbolic link: report.pdf.")
    }
}
