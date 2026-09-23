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
      try {
        hljs.highlightElement(block);
      } catch (e) {
        // Unknown/unsupported language - leave the block as plain,
        // unhighlighted text rather than failing the whole render.
      }
    }
  }

  function renderMermaidDiagrams(container) {
    if (typeof mermaid === "undefined") {
      return;
    }
    var blocks = container.querySelectorAll("code.language-mermaid");
    if (blocks.length === 0) {
      return;
    }
    try {
      mermaid.initialize({ startOnLoad: false });
    } catch (e) {
      return;
    }
    for (var i = 0; i < blocks.length; i++) {
      var block = blocks[i];
      var source = block.textContent;
      var host = document.createElement("div");
      host.className = "mermaid-diagram";
      block.parentNode.replaceWith(host);
      try {
        mermaid
          .render("mermaid-svg-" + i, source)
          .then(function (result) {
            host.innerHTML = result.svg;
          })
          .catch(function (err) {
            host.textContent = "Mermaid diagram error: " + err;
            host.classList.add("mermaid-error");
          });
      } catch (e) {
        host.textContent = "Mermaid diagram error: " + e;
        host.classList.add("mermaid-error");
      }
    }
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

  function run() {
    var sourceHolder = document.getElementById("markdown-source");
    var container = document.getElementById("markdown-body");
    if (!sourceHolder || !container) {
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
    renderMermaidDiagrams(container);
    renderMath(container);
  }

  if (document.readyState === "complete" || document.readyState === "interactive") {
    run();
  } else {
    document.addEventListener("DOMContentLoaded", run);
  }
})();
