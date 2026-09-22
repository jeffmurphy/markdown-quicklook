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
//  and completes the preview successfully, but does not yet run the real
//  Markdown-to-HTML rendering pipeline. Full implementation lands in
//  tasks 3.x (rendering pipeline) and 4.1 (preparePreviewOfFile wiring).
//

import Cocoa
import Quartz
import WebKit

class PreviewViewController: NSViewController, QLPreviewingController {

    private var webView: WKWebView!

    override func loadView() {
        let configuration = WKWebViewConfiguration()
        let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: configuration)
        self.webView = view
        self.view = view
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        let placeholder = """
        <html>
        <body style="font-family: -apple-system, sans-serif; padding: 2em; color: #333;">
        <p>Markdown Quick Look extension is installed.</p>
        <p style="color: #888;">Rendering pipeline not yet implemented (see tasks 3.x/4.1).</p>
        </body>
        </html>
        """
        webView.loadHTMLString(placeholder, baseURL: nil)
        handler(nil)
    }
}
