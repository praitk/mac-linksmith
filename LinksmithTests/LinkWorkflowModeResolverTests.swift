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

        let mode = LinkWorkflowModeResolver.mode(
            for: selection,
            isDirectory: { _ in true },
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
        #expect(didAskForFolderMode == false)
        #expect(didAskForFileMode == false)
    }

    @Test func singleFolderUsesFolderModeChooser() {
        let selection = [URL(fileURLWithPath: "/tmp/folder", isDirectory: true)]

        let mode = LinkWorkflowModeResolver.mode(
            for: selection,
            isDirectory: { _ in true },
            chooseSingleFolderMode: { .symlinkToSelectedFolder },
            chooseSingleFileMode: { .moveSelectionAndReplaceWithSymlink }
        )

        #expect(mode == .symlinkToSelectedFolder)
    }

    @Test func singleFileUsesFileModeChooser() {
        let selection = [URL(fileURLWithPath: "/tmp/report.pdf")]

        let mode = LinkWorkflowModeResolver.mode(
            for: selection,
            isDirectory: { _ in false },
            chooseSingleFolderMode: { .symlinkToSelectedFolder },
            chooseSingleFileMode: { .moveSelectionAndReplaceWithSymlink }
        )

        #expect(mode == .moveSelectionAndReplaceWithSymlink)
    }

    @Test func singleSelectionCanReturnCancelledMode() {
        let selection = [URL(fileURLWithPath: "/tmp/report.pdf")]

        let mode = LinkWorkflowModeResolver.mode(
            for: selection,
            isDirectory: { _ in false },
            chooseSingleFolderMode: { .symlinkToSelectedFolder },
            chooseSingleFileMode: { nil }
        )

        #expect(mode == nil)
    }
}
