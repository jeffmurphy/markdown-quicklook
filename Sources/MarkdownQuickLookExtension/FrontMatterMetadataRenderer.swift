//
//  FrontMatterMetadataRenderer.swift
//  MarkdownQuickLookExtension
//
//  Renders parsed front-matter key/value pairs (see FrontMatterParser) as
//  an HTML table placed above the rendered Markdown body, per
//  specs/markdown-rendering-pipeline/spec.md - Requirement: YAML front
//  matter handling. When there is no front matter, renders nothing at
//  all (an empty string) rather than an empty table shell.
//

import Foundation

enum FrontMatterMetadataRenderer {

    /// Renders the given metadata pairs as an HTML `<table>`. Returns an
    /// empty string when `metadata` is empty, so callers can simply
    /// concatenate this before the body without conditionals.
    static func renderTable(_ metadata: [(key: String, value: String)]) -> String {
        guard !metadata.isEmpty else {
            return ""
        }

        let rows = metadata
            .map { pair in
                "<tr><th>\(escapeHTML(pair.key))</th><td>\(escapeHTML(pair.value))</td></tr>"
            }
            .joined(separator: "\n")

        return """
        <table class="frontmatter-metadata">
        <tbody>
        \(rows)
        </tbody>
        </table>
        """
    }

    /// Escapes text for safe embedding in HTML. Front-matter values are
    /// arbitrary content from the previewed file, not trusted markup -
    /// this prevents both broken HTML (e.g. a value containing `<` or
    /// `&`) and injection of arbitrary tags/attributes. `&` MUST be
    /// escaped first, before the other entities are introduced, or their
    /// own `&` would be double-escaped.
    private static func escapeHTML(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        result = result.replacingOccurrences(of: "\"", with: "&quot;")
        result = result.replacingOccurrences(of: "'", with: "&#39;")
        return result
    }
}
