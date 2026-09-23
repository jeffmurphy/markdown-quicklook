//
//  PreviewDocumentAssemblerTests.swift
//  MarkdownQuickLookExtensionTests
//

import XCTest

final class PreviewDocumentAssemblerTests: XCTestCase {

    func test_assembleBodyHTML_embedsBase64EncodedSourceRoundTrippable() {
        let source = "# Hello\n\nSome *body* content with \"quotes\" & <tags>."
        let bodyHTML = PreviewDocumentAssembler.assembleBodyHTML(markdownSource: source, metadata: [])

        // Extract the base64 payload and confirm it round-trips exactly,
        // including characters that would need escaping in other embedding
        // strategies (quotes, angle brackets, ampersands).
        guard let range = bodyHTML.range(of: #"data-content="([^"]+)""#, options: .regularExpression) else {
            XCTFail("expected a data-content=\"...\" attribute in the assembled body HTML")
            return
        }
        let attr = String(bodyHTML[range])
        let base64 = attr
            .replacingOccurrences(of: "data-content=\"", with: "")
            .replacingOccurrences(of: "\"", with: "")

        guard let data = Data(base64Encoded: base64) else {
            XCTFail("expected valid base64 in the markdown-source div's data-content attribute")
            return
        }
        XCTAssertEqual(String(decoding: data, as: UTF8.self), source)
    }

    func test_assembleBodyHTML_usesHiddenDivNotMetaTagForRawSource() {
        // Regression test: a <meta> tag was tried first for embedding the
        // raw source, but empirically caused the metadata table preceding
        // it to disappear specifically inside the real Quick Look
        // extension's WKWebView (loadHTMLString), even though it rendered
        // fine in Safari. A plain hidden <div data-content="..."> is used
        // instead.
        let bodyHTML = PreviewDocumentAssembler.assembleBodyHTML(markdownSource: "text", metadata: [])
        XCTAssertFalse(bodyHTML.contains("<meta"), "must not use a <meta> tag for the raw source - see regression note above")
        XCTAssertTrue(bodyHTML.contains(#"<div id="markdown-source" hidden data-content="#))
    }

    func test_assembleBodyHTML_includesMarkdownBodyContainer() {
        let bodyHTML = PreviewDocumentAssembler.assembleBodyHTML(markdownSource: "text", metadata: [])
        XCTAssertTrue(bodyHTML.contains(#"<div id="markdown-body"></div>"#))
    }

    func test_assembleBodyHTML_includesMetadataTableBeforeContainer_whenMetadataPresent() {
        let metadata: [(key: String, value: String)] = [(key: "title", value: "Doc")]
        let bodyHTML = PreviewDocumentAssembler.assembleBodyHTML(markdownSource: "text", metadata: metadata)

        XCTAssertTrue(bodyHTML.contains("<table"))
        XCTAssertTrue(bodyHTML.contains("Doc"))

        let tableIndex = bodyHTML.range(of: "<table")!.lowerBound
        let containerIndex = bodyHTML.range(of: #"<div id="markdown-body">"#)!.lowerBound
        XCTAssertTrue(tableIndex < containerIndex, "metadata table must appear before the markdown body container")
    }

    func test_assembleBodyHTML_noMetadataTable_whenMetadataEmpty() {
        let bodyHTML = PreviewDocumentAssembler.assembleBodyHTML(markdownSource: "text", metadata: [])
        XCTAssertFalse(bodyHTML.contains("<table"))
    }

    func test_appendTruncationNotice_appendsVisibleMarkdownNotice() {
        let result = PreviewDocumentAssembler.appendTruncationNotice(to: "# Partial content")
        XCTAssertTrue(result.hasPrefix("# Partial content"))
        XCTAssertTrue(result.contains("truncated"))
    }
}
