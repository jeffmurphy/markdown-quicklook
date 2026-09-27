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

    func test_fileUnderCap_returnsFullContentNotTruncated() throws {
        let url = writeTempFile(Data("# Hello".utf8))
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try FileContentLoader.load(url: url, maxBytes: 5 * 1024 * 1024)

        XCTAssertEqual(result.text, "# Hello")
        XCTAssertFalse(result.wasTruncated)
    }

    func test_fileOverCap_isTruncatedAndFlagged() throws {
        let data = Data(repeating: 0x41, count: 1000) // 1000 'A' bytes
        let url = writeTempFile(data)
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try FileContentLoader.load(url: url, maxBytes: 100)

        XCTAssertTrue(result.wasTruncated)
        XCTAssertEqual(result.text.count, 100)
    }

    func test_fileExactlyAtCap_isNotTruncated() throws {
        let data = Data(repeating: 0x41, count: 100)
        let url = writeTempFile(data)
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try FileContentLoader.load(url: url, maxBytes: 100)

        XCTAssertFalse(result.wasTruncated)
        XCTAssertEqual(result.text.count, 100)
    }

    func test_missingFile_throwsRatherThanReturningEmptyResult() {
        let nonExistentURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + "-does-not-exist.md")

        XCTAssertThrowsError(try FileContentLoader.load(url: nonExistentURL, maxBytes: 1024))
    }

    func test_unreadableFile_throwsRatherThanReturningEmptyResult() throws {
        let url = writeTempFile(Data("secret".utf8))
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: url.path)
            try? FileManager.default.removeItem(at: url)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: url.path)

        XCTAssertThrowsError(try FileContentLoader.load(url: url, maxBytes: 1024))
    }

    func test_emptyFile_returnsEmptyNonTruncatedResult_doesNotThrow() throws {
        let url = writeTempFile(Data())
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try FileContentLoader.load(url: url, maxBytes: 1024)

        XCTAssertEqual(result.text, "")
        XCTAssertFalse(result.wasTruncated)
    }
}
