//
//  PreviewDocumentAssembler.swift
//  MarkdownQuickLookExtension
//
//  Composes the pieces built in tasks 3.2/3.3 (front-matter parsing and
//  metadata table rendering) into the `bodyHTML` that HTMLShellBuilder
//  (task 3.1) wraps into a full document. The raw Markdown source itself
//  is embedded as base64 in a hidden <div data-content="..."> element
//  (safe from HTML-entity mangling and from accidentally terminating
//  early on a literal "</script" sequence in the source - unlike
//  embedding raw text directly in a <script> body) and rendered to HTML
//  client-side by bootstrap.js via marked.js. A <meta> tag was tried
//  first but empirically disappeared - along with the metadata table
//  preceding it - specifically when loaded via WKWebView's
//  loadHTMLString(_:baseURL:) inside the real Quick Look extension
//  (it rendered fine in Safari from a real file:// navigation), so a
//  plain <div> is used instead as the more broadly-supported approach.
//

import Foundation

enum PreviewDocumentAssembler {

    /// - Parameters:
    ///   - markdownSource: The Markdown body (already stripped of front
    ///     matter by FrontMatterParser), with any truncation notice
    ///     already appended if applicable.
    ///   - metadata: Parsed front-matter key/value pairs, or empty if
    ///     there was none.
    static func assembleBodyHTML(markdownSource: String, metadata: [(key: String, value: String)]) -> String {
        let metadataTable = FrontMatterMetadataRenderer.renderTable(metadata)
        let base64Source = Data(markdownSource.utf8).base64EncodedString()

        return """
        \(metadataTable)
        <div id="markdown-source" hidden data-content="\(base64Source)"></div>
        <div id="markdown-body"></div>
        """
    }

    /// Appends a visible, Markdown-rendered notice indicating the
    /// content was truncated - see specs/markdown-quicklook-extension
    /// /spec.md - Scenario: Oversized file.
    static func appendTruncationNotice(to markdownSource: String) -> String {
        return markdownSource + "\n\n---\n\n*(Content truncated - this file exceeds the 5 MB preview limit.)*"
    }
}
