/*
 * bootstrap.js - Markdown Quick Look preview
 *
 * Our own (non-vendored) glue script. Runs client-side, after marked.js /
 * highlight.js (and optionally mermaid.js / KaTeX) have loaded, to:
 *   1. Decode the raw Markdown source embedded as base64 in
 *      <meta id="markdown-source">.
 *   2. Render it to HTML via marked.js (GFM: tables, task lists,
 *      footnotes) into #markdown-body.
 *   3. Apply highlight.js to fenced code blocks (skipping ```mermaid
 *      blocks, which mermaid.js renders itself, not highlight.js).
 *   4. Render ```mermaid blocks via mermaid.js, if loaded.
 *   5. Auto-render $...$/$$...$$ math via KaTeX's renderMathInElement,
 *      if loaded.
 *
 * Loaded via <script src="bootstrap.js"> (external file, not an inline
 * <script> block) specifically so it is permitted by the page's strict
 * Content-Security-Policy (script-src 'self' file:) without needing
 * 'unsafe-inline'. Placed at the end of <body> so the DOM (including
 * #markdown-body) is already parsed by the time it runs.
 */
(function () {
  "use strict";

  function decodeBase64Utf8(base64) {
    var binary = atob(base64);
    var bytes = new Uint8Array(binary.length);
    for (var i = 0; i < binary.length; i++) {
      bytes[i] = binary.charCodeAt(i);
    }
    return new TextDecoder("utf-8").decode(bytes);
  }

  function highlightCodeBlocks(container) {
    if (typeof hljs === "undefined") {
      return;
    }
    var blocks = container.querySelectorAll("pre code");
    for (var i = 0; i < blocks.length; i++) {
      var block = blocks[i];
      // Mermaid diagram source is not a programming language - leave it
      // untouched for mermaid.js to read as raw text.
      if (block.classList.contains("language-mermaid")) {
        continue;
      }
      // Only highlight blocks with an explicit "language-xxx" class.
      // hljs.highlightElement() auto-detects a language by default when
      // no class is present, which can apply *incorrect* highlighting to
      // plain fenced blocks with no declared language - the spec
      // requires "no highlighting" for that case, not "best guess"
      // highlighting. An explicit-but-unrecognized language class (e.g.
      // "language-notarealthing") still reaches highlightElement, which
      // correctly leaves it unstyled since no such language is
      // registered.
      var hasLanguageClass = false;
      for (var c = 0; c < block.classList.length; c++) {
        if (block.classList[c].indexOf("language-") === 0) {
          hasLanguageClass = true;
          break;
        }
      }
      if (!hasLanguageClass) {
        continue;
      }
      try {
        hljs.highlightElement(block);
      } catch (e) {
        // Unknown/unsupported language - leave the block as plain,
        // unhighlighted text rather than failing the whole render.
      }
    }
  }

  // Returns a Promise that resolves once every ```mermaid block has
  // either rendered or fallen back to an error display. mermaid.render()
  // is asynchronous (returns a Promise) - the caller MUST await this
  // before signaling completion back to Swift (see notifyRenderComplete),
  // or Quick Look may tear down the WKWebView while a render is still
  // in flight, which manifested as the whole extension crashing rather
  // than a graceful per-diagram error.
  function renderMermaidDiagrams(container) {
    if (typeof mermaid === "undefined") {
      return Promise.resolve();
    }
    var blocks = container.querySelectorAll("code.language-mermaid");
    if (blocks.length === 0) {
      return Promise.resolve();
    }
    try {
      // Mermaid's default theme renders connector lines/arrows in black,
      // which is invisible against our dark palette - use Mermaid's own
      // built-in "dark" theme when our data-theme attribute says dark,
      // matching whatever light/dark palette HTMLShellBuilder picked.
      var isDark = document.documentElement.getAttribute("data-theme") === "dark";
      // suppressErrorRendering: mermaid.js by default ALSO injects its
      // own error graphic elsewhere in the page on render failure, in
      // addition to rejecting the render() promise - we handle errors
      // ourselves below, so suppress its built-in error UI to avoid a
      // confusing duplicate error display.
      mermaid.initialize({
        startOnLoad: false,
        suppressErrorRendering: true,
        theme: isDark ? "dark" : "default",
      });
    } catch (e) {
      return Promise.resolve();
    }

    var diagramPromises = [];
    for (let i = 0; i < blocks.length; i++) {
      // `let` (not `var`) is required here: each iteration's block/
      // source/host must be captured independently by its own
      // then()/catch() closures below, which run asynchronously after
      // the loop has already finished. With `var`, all callbacks would
      // share the same last-iteration values, causing one diagram's
      // rendered SVG (or error) to be written into a different
      // diagram's placeholder.
      const block = blocks[i];
      const source = block.textContent;
      const host = document.createElement("div");
      host.className = "mermaid-diagram";
      block.parentNode.replaceWith(host);

      const diagramPromise = Promise.resolve()
        .then(function () {
          return mermaid.render("mermaid-svg-" + i, source);
        })
        .then(function (result) {
          host.innerHTML = result.svg;
        })
        .catch(function (err) {
          host.textContent = "Mermaid diagram error: " + err;
          host.classList.add("mermaid-error");
        });
      diagramPromises.push(diagramPromise);
    }
    return Promise.all(diagramPromises);
  }

  function renderMath(container) {
    if (typeof renderMathInElement === "undefined") {
      return;
    }
    try {
      renderMathInElement(container, {
        delimiters: [
          { left: "$$", right: "$$", display: true },
          { left: "$", right: "$", display: false },
        ],
        throwOnError: false,
      });
    } catch (e) {
      // Leave raw source text visible rather than failing the render -
      // renderMathInElement's own throwOnError:false already handles
      // most per-expression errors; this guards the call itself.
    }
  }

  // Tells Swift (PreviewViewController) that rendering is genuinely
  // finished - including any async work (Mermaid) - via a
  // WKScriptMessageHandler, rather than relying on WKNavigationDelegate.
  // didFinish, which only reflects the STATIC HTML/resource load and
  // fires well before our own client-side rendering (marked.parse,
  // Mermaid, KaTeX) has actually completed. Signaling completion too
  // early let Quick Look tear down the web view while a mermaid.render()
  // Promise was still in flight, which crashed the whole extension
  // rather than falling back gracefully.
  function notifyRenderComplete() {
    try {
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.renderComplete) {
        window.webkit.messageHandlers.renderComplete.postMessage("done");
      }
    } catch (e) {
      // If the message handler isn't available for some reason, there's
      // nothing more we can do from here - Swift-side fallback handling
      // (if any) takes over.
    }
  }

  function run() {
    var sourceHolder = document.getElementById("markdown-source");
    var container = document.getElementById("markdown-body");
    if (!sourceHolder || !container) {
      notifyRenderComplete();
      return;
    }

    var raw = decodeBase64Utf8(sourceHolder.getAttribute("data-content"));

    if (typeof marked !== "undefined") {
      marked.setOptions({ gfm: true, breaks: false });
      if (typeof markedFootnote !== "undefined") {
        marked.use(markedFootnote());
      }
      container.innerHTML = marked.parse(raw);
    } else {
      container.textContent = raw;
    }

    highlightCodeBlocks(container);
    renderMath(container);

    // Mermaid is the only genuinely asynchronous piece - wait for it
    // (successful or not, per-diagram errors are already handled inside
    // renderMermaidDiagrams) before telling Swift we're done.
    renderMermaidDiagrams(container)
      .catch(function () {
        // Promise.all rejects if any individual promise rejects, but
        // each one already has its own .catch() attached, so this
        // should be unreachable - kept as a final safety net so a
        // rendering completion signal is ALWAYS sent regardless.
      })
      .then(function () {
        notifyRenderComplete();
      });
  }

  if (document.readyState === "complete" || document.readyState === "interactive") {
    run();
  } else {
    document.addEventListener("DOMContentLoaded", run);
  }
})();
