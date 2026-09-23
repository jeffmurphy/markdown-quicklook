//
//  RenderingFeatureDetector.swift
//  MarkdownQuickLookExtension
//
//  Cheap, best-effort substring checks on raw Markdown source to decide
//  whether the HTML shell needs to inject the heavier optional Mermaid/
//  KaTeX libraries. Not a full Markdown/AST parse - see
//  openspec/changes/add-markdown-quicklook-preview/design.md - Decision 2
//  step 4. False positives (loading a library that turns out to be
//  unused) are acceptable; false negatives (a real mermaid/math block
//  failing to render because its library wasn't loaded) are not, so
//  these checks lean permissive.
//

import Foundation

enum RenderingFeatureDetector {

    /// Whether the source contains a fenced code block declared as
    /// `mermaid` (e.g. ` ```mermaid `).
    static func containsMermaidBlock(_ markdownSource: String) -> Bool {
        return markdownSource.contains("```mermaid")
    }

    /// Whether the source contains a block (`$$...$$`) or inline
    /// (`$...$`) math delimiter. Bare currency mentions like "$5" (a
    /// single `$` with no closing `$`) are intentionally not matched by
    /// the inline pattern to reduce false positives.
    static func containsMathDelimiter(_ markdownSource: String) -> Bool {
        if markdownSource.contains("$$") {
            return true
        }
        let inlineMathPattern = #"\$[^\s$][^$\n]*\$"#
        return markdownSource.range(of: inlineMathPattern, options: .regularExpression) != nil
    }
}
