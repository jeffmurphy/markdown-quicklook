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
//  Completion is signaled by bootstrap.js via a WKScriptMessageHandler
//  ("renderComplete"), NOT by WKNavigationDelegate.didFinish. didFinish
//  only reflects the static HTML/resource load finishing - our actual
//  rendering (marked.parse, Mermaid, KaTeX) happens afterward via
//  bootstrap.js, and Mermaid's rendering is genuinely asynchronous
//  (returns a Promise). Calling the completion handler on didFinish let
//  Quick Look tear down the web view while a mermaid.render() Promise
//  was still in flight, which crashed the whole extension (visible as
//  "Extension ... failed during preview") instead of falling back
//  gracefully - found via real end-to-end testing with a Mermaid
//  fixture, reproduced identically in a plain Safari harness with
//  byte-identical HTML/JS, confirming it was a completion-timing bug,
//  not a Mermaid-rendering-logic bug.
//

import Cocoa
import Quartz
import WebKit

class PreviewViewController: NSViewController, QLPreviewingController, WKNavigationDelegate, WKScriptMessageHandler {

    /// See design.md Decision 6. Originally set to 5MB on the (wrong)
    /// assumption that this would be "generous headroom" - empirical
    /// testing found marked.js's parse time scales roughly quadratically
    /// with input size (100KB ~0.8s, 250KB ~4.8s, 500KB ~19s, 1MB+ never
    /// completes within 30s), so 5MB was never actually renderable at
    /// all. 100KB keeps worst-case parse time well under a second with
    /// comfortable margin, and covers the overwhelming majority of real
    /// Markdown files (READMEs, notes).
    private static let maxPreviewBytes = 100 * 1024

    private static let renderCompleteMessageName = "renderComplete"

    /// Comfortably under Quick Look's own external timeout for
    /// unresponsive extensions (undocumented exact value, but generally
    /// on the order of several to ~10s) - see design.md Decision 6. If
    /// bootstrap.js's async rendering (Mermaid in particular) hasn't
    /// signaled completion by this point, we complete the preview
    /// ourselves with whatever has rendered so far, rather than risking
    /// Quick Look force-killing the whole extension.
    private static let renderTimeoutSeconds: TimeInterval = 5

    private var webView: WKWebView!
    private var completionHandler: ((Error?) -> Void)?
    private var timeoutWorkItem: DispatchWorkItem?

    override func loadView() {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(self, name: Self.renderCompleteMessageName)
        let view = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 600), configuration: configuration)
        view.autoresizingMask = [.width, .height]
        view.navigationDelegate = self
        self.webView = view
        self.view = view
    }

    deinit {
        // WKUserContentController.add(_:name:) holds a strong reference
        // to its handler (self) - remove it to break the retain cycle
        // (self -> webView -> configuration -> userContentController -> self).
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: Self.renderCompleteMessageName)
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

        scheduleRenderTimeout()
    }

    /// Completes the preview exactly once, cancelling the timeout guard
    /// regardless of which path (timeout, navigation failure, or
    /// bootstrap.js's real completion signal) got there first.
    private func complete(with error: Error?) {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        completionHandler?(error)
        completionHandler = nil
    }

    private func scheduleRenderTimeout() {
        let workItem = DispatchWorkItem { [weak self] in
            // If completionHandler is already nil, real completion (or
            // a navigation failure) already won the race - this is a
            // no-op via complete()'s own nil-coalescing, but check here
            // too to avoid doing pointless work.
            self?.complete(with: nil)
        }
        timeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.renderTimeoutSeconds, execute: workItem)
    }

    // Deliberately does NOT call the completion handler here - see the
    // type-level doc comment above. didFinish only means the static
    // HTML/resources loaded; our actual rendering (including Mermaid's
    // async work) happens afterward via bootstrap.js, which signals true
    // completion through userContentController(_:didReceive:) instead.
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        complete(with: error)
    }

    // MARK: - WKScriptMessageHandler

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.renderCompleteMessageName else {
            return
        }
        complete(with: nil)
    }
}
