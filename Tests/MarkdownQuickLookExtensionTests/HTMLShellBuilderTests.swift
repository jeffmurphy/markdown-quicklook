//
//  HTMLShellBuilderTests.swift
//  MarkdownQuickLookExtensionTests
//
//  Covers markdown-quicklook-yyp.3.1 acceptance criteria: conditional
//  Mermaid/KaTeX <script>/<link> injection based on a cheap substring
//  check of the raw Markdown source.
//

import XCTest

final class HTMLShellBuilderTests: XCTestCase {

    private let mermaidScriptTag = #"<script src="vendor/mermaid/mermaid.min.js"></script>"#
    private let katexScriptTag = #"<script src="vendor/katex/katex.min.js"></script>"#
    private let katexStyleTag = #"<link rel="stylesheet" href="vendor/katex/katex.min.css">"#

    // MARK: - Acceptance criterion 1: plain document omits both

    func test_plainDocument_omitsMermaidAndKaTeXTags() {
        let source = """
        # Hello Markdown

        This is a **plain** document with *no* diagrams or math.

        - item one
        - item two
        """

        let html = HTMLShellBuilder.build(bodyHTML: "<p>body</p>", rawMarkdownSource: source)

        XCTAssertFalse(html.contains(mermaidScriptTag), "plain document should not include the Mermaid <script> tag")
        XCTAssertFalse(html.contains(katexScriptTag), "plain document should not include the KaTeX <script> tag")
        XCTAssertFalse(html.contains(katexStyleTag), "plain document should not include the KaTeX <link> tag")
    }

    // MARK: - Acceptance criterion 2: mermaid block includes mermaid, not katex

    func test_mermaidBlock_includesMermaidTagButNotKaTeX() {
        let source = """
        # Diagram

        ```mermaid
        graph TD;
          A-->B;
        ```
        """

        let html = HTMLShellBuilder.build(bodyHTML: "<p>body</p>", rawMarkdownSource: source)

        XCTAssertTrue(html.contains(mermaidScriptTag), "mermaid document should include the Mermaid <script> tag")
        XCTAssertFalse(html.contains(katexScriptTag), "mermaid-only document should not include the KaTeX <script> tag")
        XCTAssertFalse(html.contains(katexStyleTag), "mermaid-only document should not include the KaTeX <link> tag")
    }

    // MARK: - Acceptance criterion 3: math block includes katex, not mermaid

    func test_mathBlock_includesKaTeXTagButNotMermaid() {
        let source = """
        # Math

        $$
        E = mc^2
        $$
        """

        let html = HTMLShellBuilder.build(bodyHTML: "<p>body</p>", rawMarkdownSource: source)

        XCTAssertTrue(html.contains(katexScriptTag), "math document should include the KaTeX <script> tag")
        XCTAssertTrue(html.contains(katexStyleTag), "math document should include the KaTeX <link> tag")
        XCTAssertFalse(html.contains(mermaidScriptTag), "math-only document should not include the Mermaid <script> tag")
    }

    // MARK: - Always-present tags

    func test_alwaysIncludesMarkedAndHighlightScriptTags() {
        let html = HTMLShellBuilder.build(bodyHTML: "<p>body</p>", rawMarkdownSource: "plain text")

        XCTAssertTrue(html.contains(#"<script src="vendor/marked/marked.umd.js"></script>"#))
        XCTAssertTrue(html.contains(#"<script src="vendor/highlight/highlight.min.js"></script>"#))
    }

    func test_includesContentSecurityPolicyBlockingNetworkOrigins() {
        let html = HTMLShellBuilder.build(bodyHTML: "<p>body</p>", rawMarkdownSource: "plain text")

        XCTAssertTrue(html.contains("Content-Security-Policy"))
        XCTAssertTrue(html.contains("default-src 'none'"))
        XCTAssertFalse(html.contains("http:"), "CSP must not allowlist http: origins")
        XCTAssertFalse(html.contains("https:"), "CSP must not allowlist https: origins")
    }

    func test_bodyHTMLIsEmbeddedInOutput() {
        let html = HTMLShellBuilder.build(bodyHTML: "<p>unique-marker-123</p>", rawMarkdownSource: "text")
        XCTAssertTrue(html.contains("<p>unique-marker-123</p>"))
    }

    // MARK: - Theme (data-theme attribute)

    func test_defaultTheme_isLight() {
        let html = HTMLShellBuilder.build(bodyHTML: "<p>body</p>", rawMarkdownSource: "text")
        XCTAssertTrue(html.contains(#"<html data-theme="light">"#))
    }

    func test_explicitDarkTheme_setsDataThemeAttribute() {
        let html = HTMLShellBuilder.build(
            bodyHTML: "<p>body</p>",
            options: HTMLShellBuilder.Options(theme: .dark)
        )
        XCTAssertTrue(html.contains(#"<html data-theme="dark">"#))
    }

    func test_rawMarkdownSourceConvenienceOverload_passesThemeThrough() {
        let html = HTMLShellBuilder.build(bodyHTML: "<p>body</p>", rawMarkdownSource: "text", theme: .dark)
        XCTAssertTrue(html.contains(#"<html data-theme="dark">"#))
    }

    func test_themeCSSLinkTagIsPresent() {
        let html = HTMLShellBuilder.build(bodyHTML: "<p>body</p>", rawMarkdownSource: "text")
        XCTAssertTrue(html.contains(#"<link rel="stylesheet" href="theme.css">"#))
    }
}

final class RenderingFeatureDetectorTests: XCTestCase {

    func test_containsMermaidBlock_detectsFencedMermaidBlock() {
        XCTAssertTrue(RenderingFeatureDetector.containsMermaidBlock("before\n```mermaid\ngraph TD;\n```\nafter"))
    }

    func test_containsMermaidBlock_falseForPlainText() {
        XCTAssertFalse(RenderingFeatureDetector.containsMermaidBlock("no diagrams here, just ``` code ``` blocks"))
    }

    func test_containsMathDelimiter_detectsBlockMath() {
        XCTAssertTrue(RenderingFeatureDetector.containsMathDelimiter("$$\nE = mc^2\n$$"))
    }

    func test_containsMathDelimiter_detectsInlineMath() {
        XCTAssertTrue(RenderingFeatureDetector.containsMathDelimiter("The formula $x^2 + y^2 = z^2$ is well known."))
    }

    func test_containsMathDelimiter_falseForSingleUnmatchedDollarSign() {
        // A single "$" with no closing delimiter anywhere in the text
        // should not be treated as math - avoids loading KaTeX for
        // ordinary prose mentioning a single price.
        XCTAssertFalse(RenderingFeatureDetector.containsMathDelimiter("This costs $5 in total, nothing else to see here."))
    }

    func test_containsMathDelimiter_toleratesFalsePositiveForTwoSeparateCurrencyMentions() {
        // Documented, accepted limitation: two independent currency
        // mentions in the same text (e.g. "$5 ... $10") are
        // indistinguishable from real inline math ($...$) by this cheap
        // substring heuristic. Per design.md Decision 2 step 4, false
        // positives here (loading KaTeX unnecessarily) are acceptable -
        // this test documents that behavior rather than asserting a
        // specific value, so a future, more precise heuristic isn't
        // accidentally treated as a regression.
        _ = RenderingFeatureDetector.containsMathDelimiter("This costs $5 and that costs $10 separately.")
    }

    func test_containsMathDelimiter_falseForPlainText() {
        XCTAssertFalse(RenderingFeatureDetector.containsMathDelimiter("no math delimiters in this sentence at all"))
    }
}
