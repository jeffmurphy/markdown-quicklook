//
//  FileContentLoaderTests.swift
//  MarkdownQuickLookExtensionTests
//

import XCTest

final class FileContentLoaderTests: XCTestCase {

    private func writeTempFile(_ contents: Data) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".md")
        try! contents.write(to: url)
        return url
    }

    override func tearDown() {
        // Best-effort cleanup; not asserting since it's just temp scratch space.
        super.tearDown()
    }

    func test_fileUnderCap_returnsFullContentNotTruncated() {
        let url = writeTempFile(Data("# Hello".utf8))
        defer { try? FileManager.default.removeItem(at: url) }

        let result = FileContentLoader.load(url: url, maxBytes: 5 * 1024 * 1024)

        XCTAssertEqual(result.text, "# Hello")
        XCTAssertFalse(result.wasTruncated)
    }

    func test_fileOverCap_isTruncatedAndFlagged() {
        let data = Data(repeating: 0x41, count: 1000) // 1000 'A' bytes
        let url = writeTempFile(data)
        defer { try? FileManager.default.removeItem(at: url) }

        let result = FileContentLoader.load(url: url, maxBytes: 100)

        XCTAssertTrue(result.wasTruncated)
        XCTAssertEqual(result.text.count, 100)
    }

    func test_fileExactlyAtCap_isNotTruncated() {
        let data = Data(repeating: 0x41, count: 100)
        let url = writeTempFile(data)
        defer { try? FileManager.default.removeItem(at: url) }

        let result = FileContentLoader.load(url: url, maxBytes: 100)

        XCTAssertFalse(result.wasTruncated)
        XCTAssertEqual(result.text.count, 100)
    }

    func test_unreadableOrMissingFile_returnsEmptyResultWithoutCrashing() {
        let nonExistentURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-does-not-exist.md")

        let result = FileContentLoader.load(url: nonExistentURL, maxBytes: 1024)

        XCTAssertEqual(result.text, "")
        XCTAssertFalse(result.wasTruncated)
    }

    func test_emptyFile_returnsEmptyNonTruncatedResult() {
        let url = writeTempFile(Data())
        defer { try? FileManager.default.removeItem(at: url) }

        let result = FileContentLoader.load(url: url, maxBytes: 1024)

        XCTAssertEqual(result.text, "")
        XCTAssertFalse(result.wasTruncated)
    }
}
