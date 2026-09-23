//
//  PreviewViewController.swift
//  MarkdownQuickLookExtension
//
//  View-based Quick Look preview controller. Hosts a WKWebView and
//  renders the previewed Markdown file as themed HTML using bundled,
//  offline JS (marked.js, highlight.js, Mermaid, KaTeX). See
//  openspec/changes/add-markdown-quicklook-preview/design.md - Decision 2.
//
//  Loads via loadHTMLString with baseURL = this extension's own bundle
//  Resources directory, so our own assets (theme.css, bootstrap.js,
//  vendor/*) resolve correctly via plain relative paths. This does NOT
//  yet resolve relative image/link paths from the previewed document's
//  OWN directory (e.g. "./images/pic.png") - that requires
//  loadFileURL(_:allowingReadAccessTo:) with a sandbox read-access grant
//  for the document's directory, which is task 4.2.
//

import Cocoa
import Quartz
import WebKit

class PreviewViewController: NSViewController, QLPreviewingController, WKNavigationDelegate {

    /// See design.md Decision 6. Originally set to 5MB on the (wrong)
    /// assumption that this would be "generous headroom" - empirical
    /// testing found marked.js's parse time scales roughly quadratically
    /// with input size (100KB ~0.8s, 250KB ~4.8s, 500KB ~19s, 1MB+ never
    /// completes within 30s), so 5MB was never actually renderable at
    /// all. 100KB keeps worst-case parse time well under a second with
    /// comfortable margin, and covers the overwhelming majority of real
    /// Markdown files (READMEs, notes).
    private static let maxPreviewBytes = 100 * 1024

    private var webView: WKWebView!
    private var completionHandler: ((Error?) -> Void)?

    override func loadView() {
        let configuration = WKWebViewConfiguration()
        let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: configuration)
        view.autoresizingMask = [.width, .height]
        view.navigationDelegate = self
        self.webView = view
        self.view = view
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        completionHandler = handler

        let loaded = FileContentLoader.load(url: url, maxBytes: Self.maxPreviewBytes)
        let parsed = FrontMatterParser.parse(loaded.text)

        var markdownBody = parsed.body
        if loaded.wasTruncated {
            markdownBody = PreviewDocumentAssembler.appendTruncationNotice(to: markdownBody)
        }

        let bodyHTML = PreviewDocumentAssembler.assembleBodyHTML(markdownSource: markdownBody, metadata: parsed.metadata)
        let theme = SystemAppearanceDetector.currentTheme()
        let html = HTMLShellBuilder.build(bodyHTML: bodyHTML, rawMarkdownSource: markdownBody, theme: theme)

        let resourceBaseURL = Bundle(for: Self.self).resourceURL
        webView.loadHTMLString(html, baseURL: resourceBaseURL)
    }

    // Only tell Quick Look the preview is ready once the web view has
    // actually finished painting the HTML - calling the completion handler
    // before navigation finishes can result in a blank/black preview
    // panel, since Quick Look may snapshot the view immediately.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        completionHandler?(nil)
        completionHandler = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        completionHandler?(error)
        completionHandler = nil
    }
}
