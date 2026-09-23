//
//  PreviewViewController.swift
//  MarkdownQuickLookExtension
//
//  View-based Quick Look preview controller. Hosts a WKWebView and renders
//  the previewed Markdown file as themed HTML using bundled, offline JS
//  (marked.js, highlight.js, Mermaid, KaTeX). See
//  openspec/changes/add-markdown-quicklook-preview/design.md - Decision 2.
//
//  Currently a stub for task markdown-quicklook-yyp.1.2: hosts a WKWebView
//  and completes the preview successfully once navigation finishes, but
//  does not yet run the real Markdown-to-HTML rendering pipeline. Full
//  implementation lands in tasks 3.x (rendering pipeline) and 4.1
//  (preparePreviewOfFile wiring, 5MB cap, front matter, timeout).
//

import Cocoa
import Quartz
import WebKit

class PreviewViewController: NSViewController, QLPreviewingController, WKNavigationDelegate {

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
        let placeholder = """
        <html>
        <body style="font-family: -apple-system, sans-serif; padding: 2em; color: #1d1d1f; background-color: #ffffff;">
        <h1>Markdown Quick Look</h1>
        <p>Extension installed for: \(url.lastPathComponent)</p>
        <p style="color: #888;">Rendering pipeline not yet implemented (see tasks 3.x/4.1).</p>
        </body>
        </html>
        """
        webView.loadHTMLString(placeholder, baseURL: nil)
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
