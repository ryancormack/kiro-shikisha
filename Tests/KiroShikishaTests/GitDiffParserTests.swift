import XCTest
@testable import KiroShikisha

final class GitDiffParserTests: XCTestCase {

    // MARK: - Empty Input

    func testParseEmptyDiff() {
        let result = GitDiffParser.parse("")
        XCTAssertTrue(result.isEmpty)
    }

    func testParseWhitespaceOnlyDiff() {
        let result = GitDiffParser.parse("   \n  \n")
        XCTAssertTrue(result.isEmpty)
    }

    // MARK: - Single File Modification

    func testParseSingleFileModification() {
        let rawDiff = """
        diff --git a/Sources/main.swift b/Sources/main.swift
        index abc1234..def5678 100644
        --- a/Sources/main.swift
        +++ b/Sources/main.swift
        @@ -1,5 +1,6 @@
         import Foundation
         
        -let x = 1
        +let x = 2
        +let y = 3
         
         func main() {
        """

        let result = GitDiffParser.parse(rawDiff)
        XCTAssertEqual(result.count, 1)

        let fileDiff = result[0]
        XCTAssertEqual(fileDiff.filePath, "Sources/main.swift")
        XCTAssertEqual(fileDiff.changeType, .modified)
        XCTAssertEqual(fileDiff.linesAdded, 2)
        XCTAssertEqual(fileDiff.linesRemoved, 1)
        XCTAssertFalse(fileDiff.isBinary)

        XCTAssertEqual(fileDiff.hunks.count, 1)
        let hunk = fileDiff.hunks[0]
        XCTAssertEqual(hunk.oldStart, 1)
        XCTAssertEqual(hunk.oldCount, 5)
        XCTAssertEqual(hunk.newStart, 1)
        XCTAssertEqual(hunk.newCount, 6)

        // Verify line types
        let lineTypes = hunk.lines.map { $0.type }
        XCTAssertEqual(lineTypes, [
            .context, .context, .deletion, .addition, .addition, .context, .context
        ])
    }

    // MARK: - New File

    func testParseNewFile() {
        let rawDiff = """
        diff --git a/Sources/NewFile.swift b/Sources/NewFile.swift
        new file mode 100644
        index 0000000..abc1234
        --- /dev/null
        +++ b/Sources/NewFile.swift
        @@ -0,0 +1,4 @@
        +import Foundation
        +
        +struct NewFile {
        +    let value: Int
        """

        let result = GitDiffParser.parse(rawDiff)
        XCTAssertEqual(result.count, 1)

        let fileDiff = result[0]
        XCTAssertEqual(fileDiff.filePath, "Sources/NewFile.swift")
        XCTAssertEqual(fileDiff.changeType, .created)
        XCTAssertEqual(fileDiff.linesAdded, 4)
        XCTAssertEqual(fileDiff.linesRemoved, 0)

        XCTAssertEqual(fileDiff.hunks.count, 1)
        let hunk = fileDiff.hunks[0]
        XCTAssertEqual(hunk.oldStart, 0)
        XCTAssertEqual(hunk.oldCount, 0)
        XCTAssertEqual(hunk.newStart, 1)
        XCTAssertEqual(hunk.newCount, 4)

        // All lines should be additions
        for line in hunk.lines {
            XCTAssertEqual(line.type, .addition)
            XCTAssertNil(line.oldLineNumber)
            XCTAssertNotNil(line.newLineNumber)
        }
    }

    // MARK: - Deleted File

    func testParseDeletedFile() {
        let rawDiff = """
        diff --git a/Sources/OldFile.swift b/Sources/OldFile.swift
        deleted file mode 100644
        index abc1234..0000000
        --- a/Sources/OldFile.swift
        +++ /dev/null
        @@ -1,3 +0,0 @@
        -// This file is being deleted
        -let legacy = true
        -let unused = false
        """

        let result = GitDiffParser.parse(rawDiff)
        XCTAssertEqual(result.count, 1)

        let fileDiff = result[0]
        XCTAssertEqual(fileDiff.filePath, "Sources/OldFile.swift")
        XCTAssertEqual(fileDiff.changeType, .deleted)
        XCTAssertEqual(fileDiff.linesAdded, 0)
        XCTAssertEqual(fileDiff.linesRemoved, 3)

        XCTAssertEqual(fileDiff.hunks.count, 1)
        let hunk = fileDiff.hunks[0]
        XCTAssertEqual(hunk.oldStart, 1)
        XCTAssertEqual(hunk.oldCount, 3)
        XCTAssertEqual(hunk.newStart, 0)
        XCTAssertEqual(hunk.newCount, 0)

        // All lines should be deletions
        for line in hunk.lines {
            XCTAssertEqual(line.type, .deletion)
            XCTAssertNotNil(line.oldLineNumber)
            XCTAssertNil(line.newLineNumber)
        }
    }

    // MARK: - Multi-File Diff

    func testParseMultiFileDiff() {
        let rawDiff = """
        diff --git a/Sources/main.swift b/Sources/main.swift
        index abc1234..def5678 100644
        --- a/Sources/main.swift
        +++ b/Sources/main.swift
        @@ -1,3 +1,3 @@
         import Foundation
         
        -let x = 1
        +let x = 2
        diff --git a/Sources/helper.swift b/Sources/helper.swift
        new file mode 100644
        index 0000000..abc1234
        --- /dev/null
        +++ b/Sources/helper.swift
        @@ -0,0 +1,3 @@
        +func helper() {
        +    print("help")
        +}
        """

        let result = GitDiffParser.parse(rawDiff)
        XCTAssertEqual(result.count, 2)

        XCTAssertEqual(result[0].filePath, "Sources/main.swift")
        XCTAssertEqual(result[0].changeType, .modified)
        XCTAssertEqual(result[0].linesAdded, 1)
        XCTAssertEqual(result[0].linesRemoved, 1)

        XCTAssertEqual(result[1].filePath, "Sources/helper.swift")
        XCTAssertEqual(result[1].changeType, .created)
        XCTAssertEqual(result[1].linesAdded, 3)
        XCTAssertEqual(result[1].linesRemoved, 0)
    }

    // MARK: - Multiple Hunks

    func testParseFileWithMultipleHunks() {
        let rawDiff = """
        diff --git a/Sources/app.swift b/Sources/app.swift
        index abc1234..def5678 100644
        --- a/Sources/app.swift
        +++ b/Sources/app.swift
        @@ -1,4 +1,4 @@
         import Foundation
        -import UIKit
        +import SwiftUI
         
         struct App {
        @@ -20,4 +20,5 @@
         func run() {
             setup()
        -    start()
        +    configure()
        +    start(verbose: true)
         }
        """

        let result = GitDiffParser.parse(rawDiff)
        XCTAssertEqual(result.count, 1)

        let fileDiff = result[0]
        XCTAssertEqual(fileDiff.filePath, "Sources/app.swift")
        XCTAssertEqual(fileDiff.changeType, .modified)
        XCTAssertEqual(fileDiff.hunks.count, 2)
        XCTAssertEqual(fileDiff.linesAdded, 3)
        XCTAssertEqual(fileDiff.linesRemoved, 2)

        // First hunk
        let hunk1 = fileDiff.hunks[0]
        XCTAssertEqual(hunk1.oldStart, 1)
        XCTAssertEqual(hunk1.oldCount, 4)
        XCTAssertEqual(hunk1.newStart, 1)
        XCTAssertEqual(hunk1.newCount, 4)

        // Second hunk
        let hunk2 = fileDiff.hunks[1]
        XCTAssertEqual(hunk2.oldStart, 20)
        XCTAssertEqual(hunk2.oldCount, 4)
        XCTAssertEqual(hunk2.newStart, 20)
        XCTAssertEqual(hunk2.newCount, 5)
    }

    // MARK: - Binary File

    func testParseBinaryFile() {
        let rawDiff = """
        diff --git a/Resources/image.png b/Resources/image.png
        index abc1234..def5678 100644
        Binary files a/Resources/image.png and b/Resources/image.png differ
        """

        let result = GitDiffParser.parse(rawDiff)
        XCTAssertEqual(result.count, 1)

        let fileDiff = result[0]
        XCTAssertEqual(fileDiff.filePath, "Resources/image.png")
        XCTAssertTrue(fileDiff.isBinary)
        XCTAssertTrue(fileDiff.hunks.isEmpty)
        XCTAssertEqual(fileDiff.linesAdded, 0)
        XCTAssertEqual(fileDiff.linesRemoved, 0)
    }

    // MARK: - Untracked File

    func testCreateUntrackedFileDiff() {
        let content = "line 1\nline 2\nline 3\n"
        let diff = GitDiffParser.createUntrackedFileDiff(path: "Sources/new.swift", content: content)

        XCTAssertEqual(diff.filePath, "Sources/new.swift")
        XCTAssertEqual(diff.changeType, .created)
        XCTAssertEqual(diff.linesAdded, 3)
        XCTAssertEqual(diff.linesRemoved, 0)
        XCTAssertFalse(diff.isBinary)

        XCTAssertEqual(diff.hunks.count, 1)
        let hunk = diff.hunks[0]
        XCTAssertEqual(hunk.lines.count, 3)

        for line in hunk.lines {
            XCTAssertEqual(line.type, .addition)
            XCTAssertNil(line.oldLineNumber)
            XCTAssertNotNil(line.newLineNumber)
        }

        XCTAssertEqual(hunk.lines[0].content, "line 1")
        XCTAssertEqual(hunk.lines[0].newLineNumber, 1)
        XCTAssertEqual(hunk.lines[1].content, "line 2")
        XCTAssertEqual(hunk.lines[1].newLineNumber, 2)
        XCTAssertEqual(hunk.lines[2].content, "line 3")
        XCTAssertEqual(hunk.lines[2].newLineNumber, 3)
    }

    func testCreateUntrackedFileDiffWithoutTrailingNewline() {
        let content = "single line"
        let diff = GitDiffParser.createUntrackedFileDiff(path: "file.txt", content: content)

        XCTAssertEqual(diff.linesAdded, 1)
        XCTAssertEqual(diff.hunks.count, 1)
        XCTAssertEqual(diff.hunks[0].lines.count, 1)
        XCTAssertEqual(diff.hunks[0].lines[0].content, "single line")
    }

    func testCreateUntrackedFileDiffEmptyContent() {
        let content = ""
        let diff = GitDiffParser.createUntrackedFileDiff(path: "empty.txt", content: content)

        XCTAssertEqual(diff.filePath, "empty.txt")
        XCTAssertEqual(diff.changeType, .created)
        // Empty content splits to [""] which is 1 line
        XCTAssertEqual(diff.linesAdded, 1)
    }

    // MARK: - Line Numbers

    func testLineNumbersInModification() {
        let rawDiff = """
        diff --git a/file.txt b/file.txt
        index abc1234..def5678 100644
        --- a/file.txt
        +++ b/file.txt
        @@ -3,4 +3,5 @@
         context line
        -old line
        +new line A
        +new line B
         another context
         end context
        """

        let result = GitDiffParser.parse(rawDiff)
        XCTAssertEqual(result.count, 1)

        let hunk = result[0].hunks[0]
        XCTAssertEqual(hunk.lines.count, 6)

        // Context line: old=3, new=3
        XCTAssertEqual(hunk.lines[0].oldLineNumber, 3)
        XCTAssertEqual(hunk.lines[0].newLineNumber, 3)

        // Deletion: old=4, new=nil
        XCTAssertEqual(hunk.lines[1].oldLineNumber, 4)
        XCTAssertNil(hunk.lines[1].newLineNumber)

        // Addition 1: old=nil, new=4
        XCTAssertNil(hunk.lines[2].oldLineNumber)
        XCTAssertEqual(hunk.lines[2].newLineNumber, 4)

        // Addition 2: old=nil, new=5
        XCTAssertNil(hunk.lines[3].oldLineNumber)
        XCTAssertEqual(hunk.lines[3].newLineNumber, 5)

        // Context: old=5, new=6
        XCTAssertEqual(hunk.lines[4].oldLineNumber, 5)
        XCTAssertEqual(hunk.lines[4].newLineNumber, 6)

        // Context: old=6, new=7
        XCTAssertEqual(hunk.lines[5].oldLineNumber, 6)
        XCTAssertEqual(hunk.lines[5].newLineNumber, 7)
    }

    // MARK: - GitFileDiff Computed Properties

    func testGitFileDiffFileName() {
        let diff = GitFileDiff(filePath: "Sources/Views/MainView.swift", changeType: .modified)
        XCTAssertEqual(diff.fileName, "MainView.swift")
    }

    func testGitFileDiffDirectoryPath() {
        let diff = GitFileDiff(filePath: "Sources/Views/MainView.swift", changeType: .modified)
        XCTAssertEqual(diff.directoryPath, "Sources/Views")
    }

    func testGitFileDiffFileNameTopLevel() {
        let diff = GitFileDiff(filePath: "README.md", changeType: .modified)
        XCTAssertEqual(diff.fileName, "README.md")
        XCTAssertEqual(diff.directoryPath, "")
    }

    // MARK: - No Newline at End of File

    func testParseNoNewlineAtEndOfFile() {
        let rawDiff = """
        diff --git a/file.txt b/file.txt
        index abc1234..def5678 100644
        --- a/file.txt
        +++ b/file.txt
        @@ -1,2 +1,2 @@
         first line
        -old last line
        +new last line
        \\ No newline at end of file
        """

        let result = GitDiffParser.parse(rawDiff)
        XCTAssertEqual(result.count, 1)

        let hunk = result[0].hunks[0]
        // The "\ No newline" line should be skipped
        XCTAssertEqual(hunk.lines.count, 3)
        XCTAssertEqual(hunk.lines[0].type, .context)
        XCTAssertEqual(hunk.lines[1].type, .deletion)
        XCTAssertEqual(hunk.lines[2].type, .addition)
    }

    // MARK: - Hunk Header Context

    func testHunkHeaderWithFunctionContext() {
        let rawDiff = """
        diff --git a/file.swift b/file.swift
        index abc1234..def5678 100644
        --- a/file.swift
        +++ b/file.swift
        @@ -10,3 +10,4 @@ func myFunction() {
         let a = 1
        -let b = 2
        +let b = 3
        +let c = 4
        """

        let result = GitDiffParser.parse(rawDiff)
        XCTAssertEqual(result.count, 1)

        let hunk = result[0].hunks[0]
        XCTAssertTrue(hunk.header.contains("func myFunction()"))
        XCTAssertEqual(hunk.oldStart, 10)
        XCTAssertEqual(hunk.oldCount, 3)
        XCTAssertEqual(hunk.newStart, 10)
        XCTAssertEqual(hunk.newCount, 4)
    }

    // MARK: - Rename Detection

    func testParseRenamedFile() {
        let rawDiff = """
        diff --git a/old_name.swift b/new_name.swift
        similarity index 90%
        rename from old_name.swift
        rename to new_name.swift
        index abc1234..def5678 100644
        --- a/old_name.swift
        +++ b/new_name.swift
        @@ -1,3 +1,3 @@
         import Foundation
        -let name = "old"
        +let name = "new"
        """

        let result = GitDiffParser.parse(rawDiff)
        XCTAssertEqual(result.count, 1)

        let fileDiff = result[0]
        XCTAssertEqual(fileDiff.filePath, "new_name.swift")
        XCTAssertEqual(fileDiff.changeType, .modified)
        XCTAssertEqual(fileDiff.linesAdded, 1)
        XCTAssertEqual(fileDiff.linesRemoved, 1)
    }
}
