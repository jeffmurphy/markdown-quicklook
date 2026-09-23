//
//  FrontMatterMetadataRendererTests.swift
//  MarkdownQuickLookExtensionTests
//
//  Covers markdown-quicklook-yyp.3.3 acceptance criteria.
//

import XCTest

final class FrontMatterMetadataRendererTests: XCTestCase {

    // MARK: - Acceptance criterion 1: front matter present

    func test_frontMatterPresent_producesTableWithNoRawDelimitersOrYAMLSyntax() {
        let source = """
        ---
        title: My Document
        author: Jane Doe
        ---
        # Hello

        Body content.
        """
        let parsed = FrontMatterParser.parse(source)
        let table = FrontMatterMetadataRenderer.renderTable(parsed.metadata)

        XCTAssertTrue(table.contains("<table"))
        XCTAssertTrue(table.contains("My Document"))
        XCTAssertTrue(table.contains("Jane Doe"))
        XCTAssertFalse(table.contains("---"), "raw --- delimiters must not appear in the rendered table")
        XCTAssertFalse(table.contains("title:"), "raw 'key:' YAML syntax must not appear in the rendered table")
        XCTAssertFalse(table.contains("author:"))

        // Table must be distinct from (not embedded inside) the parsed body.
        XCTAssertFalse(parsed.body.contains("<table"))
        XCTAssertFalse(parsed.body.contains("My Document"))
    }

    // MARK: - Acceptance criterion 2: no front matter present

    func test_noFrontMatter_producesNoTableAtAll() {
        let source = "# Hello\n\nJust a normal document."
        let parsed = FrontMatterParser.parse(source)
        let table = FrontMatterMetadataRenderer.renderTable(parsed.metadata)

        XCTAssertEqual(table, "", "no front matter should render no table markup at all")
    }

    // MARK: - HTML escaping

    func test_valuesContainingHTMLSpecialCharacters_areEscaped() {
        let metadata: [(key: String, value: String)] = [
            (key: "title", value: "<script>alert(1)</script> & \"quoted\" 'text'")
        ]

        let table = FrontMatterMetadataRenderer.renderTable(metadata)

        XCTAssertFalse(table.contains("<script>"), "raw script tags must be escaped, not passed through")
        XCTAssertTrue(table.contains("&lt;script&gt;"))
        XCTAssertTrue(table.contains("&amp;"))
        XCTAssertTrue(table.contains("&quot;quoted&quot;"))
        XCTAssertTrue(table.contains("&#39;text&#39;"))
    }

    func test_keysContainingAmpersand_areEscapedWithoutDoubleEscaping() {
        let metadata: [(key: String, value: String)] = [(key: "R&D", value: "value")]
        let table = FrontMatterMetadataRenderer.renderTable(metadata)

        XCTAssertTrue(table.contains("R&amp;D"))
        XCTAssertFalse(table.contains("&amp;amp;"), "ampersand must not be double-escaped")
    }

    func test_emptyMetadataArray_producesEmptyString() {
        XCTAssertEqual(FrontMatterMetadataRenderer.renderTable([]), "")
    }
}
