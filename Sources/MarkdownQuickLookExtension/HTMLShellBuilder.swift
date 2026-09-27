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

    /// Which light/dark palette the theme CSS should apply, keyed off a
    /// `data-theme` attribute on `<html>` rather than relying solely on
    /// the web view's own `prefers-color-scheme` media query propagation
    /// (see design.md Decision 5 - deterministic regardless of whether
    /// the hosting environment reliably forwards the system appearance).
    enum Theme: String {
        case light
        case dark
    }

    struct Options {
        var includeMermaid: Bool
        var includeKaTeX: Bool
        var theme: Theme

        init(includeMermaid: Bool = false, includeKaTeX: Bool = false, theme: Theme = .light) {
            self.includeMermaid = includeMermaid
            self.includeKaTeX = includeKaTeX
            self.theme = theme
        }
    }

    /// - Parameters:
    ///   - bodyHTML: Pre-rendered content to place inside `<body>` (e.g. a
    ///     front-matter metadata table plus a container for the raw
    ///     Markdown source that marked.js will render client-side).
    ///   - options: Which optional libraries to inject `<script>`/`<link>`
    ///     tags for.
    static func build(bodyHTML: String, options: Options) -> String {
        let highlightThemeCSS = options.theme == .dark
            ? #"<link rel="stylesheet" href="vendor/highlight/styles/github-dark.min.css">"#
            : #"<link rel="stylesheet" href="vendor/highlight/styles/github.min.css">"#

        var headTags: [String] = [
            #"<meta charset="utf-8">"#,
            contentSecurityPolicyTag,
            #"<link rel="stylesheet" href="theme.css">"#,
            highlightThemeCSS,
            #"<script src="vendor/marked/marked.umd.js"></script>"#,
            #"<script src="vendor/marked/marked-footnote.umd.js"></script>"#,
            #"<script src="vendor/highlight/highlight.min.js"></script>"#,
        ]

        if options.includeMermaid {
            headTags.append(#"<script src="vendor/mermaid/mermaid.min.js"></script>"#)
        }
        if options.includeKaTeX {
            headTags.append(#"<link rel="stylesheet" href="vendor/katex/katex.min.css">"#)
            headTags.append(#"<script src="vendor/katex/katex.min.js"></script>"#)
            headTags.append(#"<script src="vendor/katex/contrib/auto-render.min.js"></script>"#)
        }

        let head = headTags.joined(separator: "\n    ")

        return """
        <!DOCTYPE html>
        <html data-theme="\(options.theme.rawValue)">
        <head>
            \(head)
        </head>
        <body>
        \(bodyHTML)
        <script src="bootstrap.js"></script>
        </body>
        </html>
        """
    }

    /// Convenience overload that runs the cheap substring detection on the
    /// raw Markdown source and builds accordingly.
    static func build(bodyHTML: String, rawMarkdownSource: String, theme: Theme = .light) -> String {
        let options = Options(
            includeMermaid: RenderingFeatureDetector.containsMermaidBlock(rawMarkdownSource),
            includeKaTeX: RenderingFeatureDetector.containsMathDelimiter(rawMarkdownSource),
            theme: theme
        )
        return build(bodyHTML: bodyHTML, options: options)
    }

    /// A minimal, styled error page - used when the file can't be read
    /// at all (permissions, I/O error), as opposed to a genuinely empty
    /// file (which renders through the normal pipeline with an empty
    /// #markdown-body - no special-casing needed for that case). No
    /// marked.js/highlight.js/bootstrap.js are needed since there is no
    /// Markdown to render, only a static message.
    static func buildErrorPage(message: String, theme: Theme = .light) -> String {
        return """
        <!DOCTYPE html>
        <html data-theme="\(theme.rawValue)">
        <head>
            <meta charset="utf-8">
            \(contentSecurityPolicyTag)
            <link rel="stylesheet" href="theme.css">
        </head>
        <body>
        <div class="error-state">\(escapeHTML(message))</div>
        </body>
        </html>
        """
    }

    private static func escapeHTML(_ text: String) -> String {
        var result = text
        result = result.replacingOccurrences(of: "&", with: "&amp;")
        result = result.replacingOccurrences(of: "<", with: "&lt;")
        result = result.replacingOccurrences(of: ">", with: "&gt;")
        return result
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
