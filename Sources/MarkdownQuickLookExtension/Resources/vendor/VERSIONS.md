# Vendored Rendering Assets

Third-party JS/CSS libraries bundled offline into the `MarkdownQuickLookExtension`
for the Markdown rendering pipeline. See
`openspec/changes/add-markdown-quicklook-preview/design.md` - Decision 3
(vendored, pinned assets; no network access at build or runtime).

Fetched via `scripts/fetch-vendor-assets.sh`. Re-run that script to refresh
these files after deliberately bumping a version below - do not hand-edit
the vendored files themselves.

| Library | Version | License | Source | Vendored as |
|---|---|---|---|---|
| [marked](https://github.com/markedjs/marked) | 18.0.14 | MIT | `https://cdn.jsdelivr.net/npm/marked@18.0.14/lib/marked.umd.js` | `marked/marked.umd.js` |
| [highlight.js](https://github.com/highlightjs/highlight.js) | 11.11.2 | BSD-3-Clause | `https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.11.2/highlight.min.js` | `highlight/highlight.min.js` |
| highlight.js theme (light) | 11.11.2 | BSD-3-Clause | `https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.11.2/styles/github.min.css` | `highlight/styles/github.min.css` |
| highlight.js theme (dark) | 11.11.2 | BSD-3-Clause | `https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.11.2/styles/github-dark.min.css` | `highlight/styles/github-dark.min.css` |
| [mermaid](https://github.com/mermaid-js/mermaid) | 12.0.0 | MIT | `https://cdn.jsdelivr.net/npm/mermaid@12.0.0/dist/mermaid.min.js` | `mermaid/mermaid.min.js` |
| [katex](https://github.com/KaTeX/KaTeX) | 0.18.7 | MIT | `https://github.com/KaTeX/KaTeX/releases/download/v0.18.7/katex.tar.gz` (extracted) | `katex/katex.min.js`, `katex/katex.min.css`, `katex/fonts/*`, `katex/contrib/auto-render.min.js` |

## Notes

- **marked**: current releases (v13+) no longer publish a root `marked.min.js`;
  the browser-ready build is `lib/marked.umd.js` (unminified but small, ~46KB).
- **highlight.js**: the cdnjs-hosted `highlight.min.js` bundle includes the
  "common" language subset (~128KB) - confirmed to include python, rust,
  swift, typescript, etc. - not the full 192-language grammar set, keeping
  bundle size down per design.md Decision 3.
- **katex**: fonts directory includes `.ttf`/`.woff`/`.woff2` variants for
  each glyph set (61 files total) as shipped in the official release
  tarball; `.woff2` is what WebKit will actually use, the others are
  legacy-browser fallbacks kept for simplicity of vendoring the full
  official release as-is.

## Updating

To bump a version: edit the version variables at the top of
`scripts/fetch-vendor-assets.sh`, re-run it, update the table above, and
verify the extension still builds and renders correctly (tasks 3.x/4.x
fixtures) before committing.
