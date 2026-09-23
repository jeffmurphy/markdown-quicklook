//
//  FrontMatterParserTests.swift
//  MarkdownQuickLookExtensionTests
//
//  Covers markdown-quicklook-yyp.3.2 acceptance criteria.
//

import XCTest

final class FrontMatterParserTests: XCTestCase {

    // MARK: - Acceptance criterion 1: well-formed front matter

    func test_wellFormedFrontMatter_parsesKeyValuePairsAndStripsBody() {
        let source = """
        ---
        title: My Document
        author: Jane Doe
        ---
        # Hello

        Body content here.
        """

        let result = FrontMatterParser.parse(source)

        XCTAssertEqual(result.metadata.count, 2)
        XCTAssertEqual(result.metadata[0].key, "title")
        XCTAssertEqual(result.metadata[0].value, "My Document")
        XCTAssertEqual(result.metadata[1].key, "author")
        XCTAssertEqual(result.metadata[1].value, "Jane Doe")
        XCTAssertEqual(result.body, "# Hello\n\nBody content here.")
        XCTAssertFalse(result.body.contains("---"), "the --- delimiters must not remain in the body")
        XCTAssertFalse(result.body.contains("title:"), "front matter content must not leak into the body")
    }

    // MARK: - Acceptance criterion 2: no front matter

    func test_noFrontMatter_returnsEmptyMetadataAndUnchangedBody() {
        let source = "# Hello\n\nJust a normal document, no front matter."

        let result = FrontMatterParser.parse(source)

        XCTAssertTrue(result.metadata.isEmpty)
        XCTAssertEqual(result.body, source, "body must be returned completely unchanged")
    }

    // MARK: - Acceptance criterion 3: malformed/unterminated front matter

    func test_unterminatedFrontMatter_degradesToWholeFileAsBodyWithNoMetadata() {
        let source = """
        ---
        title: Unterminated
        # Hello

        No closing delimiter anywhere in this file.
        """

        let result = FrontMatterParser.parse(source)

        XCTAssertTrue(result.metadata.isEmpty)
        XCTAssertEqual(result.body, source, "unterminated block must degrade to treating the whole file as body, unchanged")
    }

    func test_doesNotCrash_onEmptyFile() {
        let result = FrontMatterParser.parse("")
        XCTAssertTrue(result.metadata.isEmpty)
        XCTAssertEqual(result.body, "")
    }

    func test_doesNotCrash_onLoneDashesWithNothingElse() {
        let result = FrontMatterParser.parse("---")
        XCTAssertTrue(result.metadata.isEmpty)
        XCTAssertEqual(result.body, "---")
    }

    // MARK: - Non-scalar values degrade gracefully rather than crashing

    func test_nestedListValue_isAppendedAsRawTextRatherThanCrashing() {
        let source = """
        ---
        title: Doc With List
        tags:
          - swift
          - macos
        ---
        Body.
        """

        let result = FrontMatterParser.parse(source)

        XCTAssertEqual(result.metadata.count, 2)
        XCTAssertEqual(result.metadata[0].key, "title")
        XCTAssertEqual(result.metadata[1].key, "tags")
        // The nested list items are appended as raw text, not deeply
        // parsed into an actual array - this documents the "literal raw
        // text" fallback behavior rather than asserting a specific
        // internal format.
        XCTAssertTrue(result.metadata[1].value.contains("swift"))
        XCTAssertTrue(result.metadata[1].value.contains("macos"))
        XCTAssertEqual(result.body, "Body.")
    }

    // MARK: - Empty front matter block

    func test_emptyFrontMatterBlock_parsesToEmptyMetadataWithBodyStripped() {
        let source = "---\n---\nJust the body."

        let result = FrontMatterParser.parse(source)

        XCTAssertTrue(result.metadata.isEmpty)
        XCTAssertEqual(result.body, "Just the body.")
    }

    // MARK: - Values containing a colon

    func test_valueContainingColon_onlySplitsOnFirstColon() {
        let source = "---\nurl: https://example.com:8080/path\n---\nBody"

        let result = FrontMatterParser.parse(source)

        XCTAssertEqual(result.metadata.count, 1)
        XCTAssertEqual(result.metadata[0].key, "url")
        XCTAssertEqual(result.metadata[0].value, "https://example.com:8080/path")
    }
}
