import Foundation
import Testing
@testable import Linksmith

struct LinkWorkflowModeResolverTests {
    @Test func multipleSelectionDefaultsToCreateLinksFromSelection() {
        let selection = [
            URL(fileURLWithPath: "/tmp/one.txt"),
            URL(fileURLWithPath: "/tmp/two.txt"),
        ]
        var didAskForFolderMode = false
        var didAskForFileMode = false
        var didAskForSymlinkMode = false

        let mode = LinkWorkflowModeResolver.mode(
            for: selection,
            isSymbolicLink: { _ in true },
            isDirectory: { _ in true },
            chooseSymlinkMode: {
                didAskForSymlinkMode = true
                return .swapSymlinkTarget
            },
            chooseSingleFolderMode: {
                didAskForFolderMode = true
                return .symlinkToSelectedFolder
            },
            chooseSingleFileMode: {
                didAskForFileMode = true
                return .moveSelectionAndReplaceWithSymlink
            }
        )

        #expect(mode == .symlinkFromSelection)
        #expect(didAskForSymlinkMode == false)
        #expect(didAskForFolderMode == false)
        #expect(didAskForFileMode == false)
    }

    @Test func singleFolderUsesFolderModeChooser() {
        let selection = [URL(fileURLWithPath: "/tmp/folder", isDirectory: true)]

        let mode = LinkWorkflowModeResolver.mode(
            for: selection,
            isSymbolicLink: { _ in false },
            isDirectory: { _ in true },
            chooseSymlinkMode: { .swapSymlinkTarget },
            chooseSingleFolderMode: { .symlinkToSelectedFolder },
            chooseSingleFileMode: { .moveSelectionAndReplaceWithSymlink }
        )

        #expect(mode == .symlinkToSelectedFolder)
    }

    @Test func singleFileUsesFileModeChooser() {
        let selection = [URL(fileURLWithPath: "/tmp/report.pdf")]

        let mode = LinkWorkflowModeResolver.mode(
            for: selection,
            isSymbolicLink: { _ in false },
            isDirectory: { _ in false },
            chooseSymlinkMode: { .swapSymlinkTarget },
            chooseSingleFolderMode: { .symlinkToSelectedFolder },
            chooseSingleFileMode: { .moveSelectionAndReplaceWithSymlink }
        )

        #expect(mode == .moveSelectionAndReplaceWithSymlink)
    }

    @Test func singleSelectionCanReturnCancelledMode() {
        let selection = [URL(fileURLWithPath: "/tmp/report.pdf")]

        let mode = LinkWorkflowModeResolver.mode(
            for: selection,
            isSymbolicLink: { _ in false },
            isDirectory: { _ in false },
            chooseSymlinkMode: { .swapSymlinkTarget },
            chooseSingleFolderMode: { .symlinkToSelectedFolder },
            chooseSingleFileMode: { nil }
        )

        #expect(mode == nil)
    }

    @Test func singleSymlinkUsesSymlinkModeChooserBeforeFolderOrFileMode() {
        let selection = [URL(fileURLWithPath: "/tmp/link")]
        var didCheckDirectory = false

        let mode = LinkWorkflowModeResolver.mode(
            for: selection,
            isSymbolicLink: { _ in true },
            isDirectory: { _ in
                didCheckDirectory = true
                return true
            },
            chooseSymlinkMode: { .copySymlinkTargetReplacingLink },
            chooseSingleFolderMode: { .symlinkToSelectedFolder },
            chooseSingleFileMode: { .moveSelectionAndReplaceWithSymlink }
        )

        #expect(mode == .copySymlinkTargetReplacingLink)
        #expect(didCheckDirectory == false)
    }

    @Test func singleSymlinkCanReturnCancelledMode() {
        let selection = [URL(fileURLWithPath: "/tmp/link")]

        let mode = LinkWorkflowModeResolver.mode(
            for: selection,
            isSymbolicLink: { _ in true },
            isDirectory: { _ in false },
            chooseSymlinkMode: { nil },
            chooseSingleFolderMode: { .symlinkToSelectedFolder },
            chooseSingleFileMode: { .moveSelectionAndReplaceWithSymlink }
        )

        #expect(mode == nil)
    }
}
