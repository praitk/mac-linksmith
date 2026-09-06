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
        #expect(content.informativeText == "Created relative symbolic link: report 2.pdf.")
    }

    @Test func singleLinkCompletionMentionsAbsoluteLinkStyle() {
        let created = CreatedSymlink(
            source: URL(fileURLWithPath: "/tmp/source/report.pdf"),
            link: URL(fileURLWithPath: "/tmp/links/report 2.pdf"),
            targetPath: "/tmp/source/report.pdf"
        )

        let content = LinkCompletionAlertContent.createdLinks([created])

        #expect(content.message == "Link Created")
        #expect(content.informativeText == "Created absolute symbolic link: report 2.pdf.")
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
                targetPath: "/tmp/source/image.png"
            ),
        ]

        let content = LinkCompletionAlertContent.createdLinks(created)

        #expect(content.message == "Links Created")
        #expect(content.informativeText == "Created 2 symbolic links:\nreport 2.pdf (relative)\nimage.png (absolute)")
    }

    @Test func batchPlanReviewMentionsPlannedRenamedLinks() {
        let plan = LinkCreationPlan(items: [
            LinkCreationPlanItem(
                source: URL(fileURLWithPath: "/tmp/source/report.pdf"),
                link: URL(fileURLWithPath: "/tmp/links/report.pdf"),
                targetPath: "../source/report.pdf"
            ),
            LinkCreationPlanItem(
                source: URL(fileURLWithPath: "/tmp/other/report.pdf"),
                link: URL(fileURLWithPath: "/tmp/links/report 2.pdf"),
                targetPath: "../other/report.pdf"
            ),
        ])

        let content = LinkCreationPlanAlertContent.review(plan)

        #expect(content.message == "Create 2 Symbolic Links?")
        #expect(content.informativeText == "Linksmith will create these links:\nreport.pdf -> report.pdf\nreport.pdf -> report 2.pdf (renamed)")
    }

    @Test func batchPlanReviewSummarizesLongPlans() {
        let items = (1...13).map { index in
            LinkCreationPlanItem(
                source: URL(fileURLWithPath: "/tmp/source/item\(index).txt"),
                link: URL(fileURLWithPath: "/tmp/links/item\(index).txt"),
                targetPath: "../source/item\(index).txt"
            )
        }

        let content = LinkCreationPlanAlertContent.review(LinkCreationPlan(items: items))

        #expect(content.message == "Create 13 Symbolic Links?")
        #expect(content.informativeText.hasSuffix("\n...and 1 more."))
    }

    @Test func moveAndReplaceCompletionMentionsMovedFileAndCreatedLinkName() {
        let replaced = ReplacedItemSymlink(
            original: URL(fileURLWithPath: "/tmp/source/report.pdf"),
            movedItem: URL(fileURLWithPath: "/tmp/moved/report.pdf"),
            targetPath: "../moved/report.pdf"
        )

        let content = LinkCompletionAlertContent.replacedItem(replaced)

        #expect(content.message == "File Moved")
        #expect(content.informativeText == "Moved report.pdf and created relative symbolic link: report.pdf.")
    }

    @Test func moveAndReplaceCompletionMentionsAbsoluteLinkStyle() {
        let replaced = ReplacedItemSymlink(
            original: URL(fileURLWithPath: "/tmp/source/report.pdf"),
            movedItem: URL(fileURLWithPath: "/tmp/moved/report.pdf"),
            targetPath: "/tmp/moved/report.pdf"
        )

        let content = LinkCompletionAlertContent.replacedItem(replaced)

        #expect(content.message == "File Moved")
        #expect(content.informativeText == "Moved report.pdf and created absolute symbolic link: report.pdf.")
    }

    @Test func copiedSymlinkTargetCompletionMentionsReplacedLinkName() {
        let replaced = ReplacedSymlinkTarget(
            symbolicLink: URL(fileURLWithPath: "/tmp/link/report.pdf"),
            originalTargetPath: "../target/report.pdf",
            resolvedTarget: URL(fileURLWithPath: "/tmp/target/report.pdf")
        )

        let content = LinkCompletionAlertContent.copiedSymlinkTarget(replaced)

        #expect(content.message == "File Copied")
        #expect(content.informativeText == "Copied report.pdf and replaced symbolic link: report.pdf.")
    }

    @Test func movedSymlinkTargetCompletionMentionsReplacedLinkName() {
        let replaced = ReplacedSymlinkTarget(
            symbolicLink: URL(fileURLWithPath: "/tmp/link/report.pdf"),
            originalTargetPath: "../target/report.pdf",
            resolvedTarget: URL(fileURLWithPath: "/tmp/target/report.pdf")
        )

        let content = LinkCompletionAlertContent.movedSymlinkTarget(replaced)

        #expect(content.message == "File Moved")
        #expect(content.informativeText == "Moved report.pdf and replaced symbolic link: report.pdf.")
    }

    @Test func swappedSymlinkTargetCompletionMentionsReplacementLinkNameAndStyle() {
        let swapped = SwappedSymlinkTarget(
            originalSymbolicLink: URL(fileURLWithPath: "/tmp/link/report.pdf"),
            movedItem: URL(fileURLWithPath: "/tmp/link/report.pdf"),
            replacementSymbolicLink: URL(fileURLWithPath: "/tmp/target/report.pdf"),
            replacementTargetPath: "../link/report.pdf"
        )

        let content = LinkCompletionAlertContent.swappedSymlinkTarget(swapped)

        #expect(content.message == "Files Swapped")
        #expect(content.informativeText == "Moved report.pdf into place and created relative symbolic link: report.pdf.")
    }
}
