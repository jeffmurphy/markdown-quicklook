//
//  HTMLShellBuilder.swift
//  MarkdownQuickLookExtension
//
//  Assembles the static HTML document shell that hosts the rendered
//  Markdown preview: a strict Content-Security-Policy, theme CSS,
//  marked.js/highlight.js (always present), and Mermaid/KaTeX (only when
//  RenderingFeatureDetector finds a trigger in the raw source). This type
//  does not render Markdown itself - that happens client-side via
//  marked.js once the page loads. See
//  openspec/changes/add-markdown-quicklook-preview/design.md - Decision 2
//  (steps 3-4) and Decision 4 (why the CSP exists: the extension's
//  com.apple.security.network.client entitlement is required for
//  WKWebView's helper processes to function at all, so the CSP - not the
//  entitlement's absence - is what actually enforces "no network
//  requests" at the content level).
//

import Foundation

enum HTMLShellBuilder {

    struct Options {
        var includeMermaid: Bool
        var includeKaTeX: Bool

        init(includeMermaid: Bool = false, includeKaTeX: Bool = false) {
            self.includeMermaid = includeMermaid
            self.includeKaTeX = includeKaTeX
        }
    }

    /// - Parameters:
    ///   - bodyHTML: Pre-rendered content to place inside `<body>` (e.g. a
    ///     front-matter metadata table plus a container for the raw
    ///     Markdown source that marked.js will render client-side).
    ///   - options: Which optional libraries to inject `<script>`/`<link>`
    ///     tags for.
    static func build(bodyHTML: String, options: Options) -> String {
        var headTags: [String] = [
            #"<meta charset="utf-8">"#,
            contentSecurityPolicyTag,
            #"<link rel="stylesheet" href="theme.css">"#,
            #"<script src="vendor/marked/marked.umd.js"></script>"#,
            #"<script src="vendor/highlight/highlight.min.js"></script>"#,
        ]

        if options.includeMermaid {
            headTags.append(#"<script src="vendor/mermaid/mermaid.min.js"></script>"#)
        }
        if options.includeKaTeX {
            headTags.append(#"<link rel="stylesheet" href="vendor/katex/katex.min.css">"#)
            headTags.append(#"<script src="vendor/katex/katex.min.js"></script>"#)
        }

        let head = headTags.joined(separator: "\n    ")

        return """
        <!DOCTYPE html>
        <html>
        <head>
            \(head)
        </head>
        <body>
        \(bodyHTML)
        </body>
        </html>
        """
    }

    /// Convenience overload that runs the cheap substring detection on the
    /// raw Markdown source and builds accordingly.
    static func build(bodyHTML: String, rawMarkdownSource: String) -> String {
        let options = Options(
            includeMermaid: RenderingFeatureDetector.containsMermaidBlock(rawMarkdownSource),
            includeKaTeX: RenderingFeatureDetector.containsMathDelimiter(rawMarkdownSource)
        )
        return build(bodyHTML: bodyHTML, options: options)
    }

    /// Blocks any outbound network request the page content could
    /// otherwise attempt (http:/https:/etc.), while still allowing
    /// same-origin and `file:` resources - everything this extension
    /// loads (marked.js, highlight.js, our theme CSS, vendored assets,
    /// and any relative images/links in the previewed document) is a
    /// local `file://` resource, never a remote origin.
    private static var contentSecurityPolicyTag: String {
        let policy = [
            "default-src 'none'",
            "script-src 'self' file:",
            "style-src 'self' file: 'unsafe-inline'",
            "img-src 'self' file: data:",
            "font-src 'self' file:",
            "connect-src 'none'",
        ].joined(separator: "; ")
        return #"<meta http-equiv="Content-Security-Policy" content="\#(policy)">"#
    }
}
