## Context

See `proposal.md` - Why. This is a greenfield repo; there is no existing code or prior architecture to work around. Constraints locked by the user before this design:

- Render via a `WKWebView` fed by JS libraries (`marked.js` for GFM parsing, `highlight.js` for code highlighting, plus Mermaid and KaTeX), not a native Swift Markdown renderer.
- Only `.md` triggers the preview (not `.markdown`, `.mdown`, etc.).
- Target macOS 13 (Ventura)+, local unsigned build only (no paid Developer ID / notarization in this change).
- Modern Quick Look extensions are App Extensions (`QLPreviewingController`), which macOS requires to be embedded inside a host `.app` - the host app itself has no meaningful UI beyond an "About/Status" screen; it exists so the extension can be discovered, registered, and (un)installed.

## Goals / Non-Goals

**Goals:**
- Concrete Xcode project layout (host app target + extension target) and how they relate.
- How Markdown source becomes a themed HTML document inside the extension's `WKWebView`, entirely offline.
- How front matter, relative images/links, Mermaid, and KaTeX are handled end-to-end.
- How the App Sandbox and file-access model work for a Quick Look extension.
- Concrete build/install/uninstall mechanics (`xcodebuild`, Launch Services, Quick Look cache).

**Non-Goals:**
- Code signing with a paid Apple Developer ID, notarization, or App Store packaging (explicitly deferred per proposal).
- Supporting file extensions other than `.md`.
- A plugin/settings UI for end users to customize theme or features.

## Decisions

### 1. Xcode project layout: host app + embedded App Extension
- **Host app** (`Markdown Quick Look.app`, SwiftUI, minimal): on launch shows a small status window ("Extension installed - Quick Look any `.md` file to preview it") and nothing else. Its only real job is to exist so macOS registers the embedded extension.
- **Extension target** (`MarkdownQuickLookExtension.appex`, extension point `com.apple.quicklook.preview`): implements `QLPreviewingController`.
- Alternative considered: a Finder Sync / Automator-based approach - rejected because `QLPreviewingController` is Apple's current, supported mechanism for rich Quick Look previews; older `QuickLookGeneratorPluGin` (`.qlgenerator`, `QLPreviewProvider` C API) bundles are deprecated on modern macOS and QuickLook no longer reliably loads them outside a signed, `/Library/QuickLook`-installed legacy path.

### 2. Rendering pipeline lives entirely inside the extension process
`QLPreviewingController.preparePreviewOfFile(at:completionHandler:)` (the view-based Quick Look preview API - required, rather than the data-based `providePreview(for:completionHandler:)` API, because the latter has the system render static reply data and does not reliably execute the `<script>`-driven JS renderer this design depends on) does, in order:
1. Read the file's raw bytes (capped - see Decision 6).
2. Detect and strip a leading YAML front matter block using a minimal line-based parser (`key: value` pairs only - no external YAML dependency, since the spec only requires flat metadata-table rendering, not full YAML semantics). Non-scalar/nested values are shown as their literal raw text in the table rather than being interpreted.
3. Wrap the remaining Markdown body plus the front matter table (if any) into a static HTML shell that references bundled, vendored JS/CSS via relative `file://` paths inside the extension bundle: `marked.min.js`, a curated `highlight.js` build with a common-language subset, `mermaid.min.js`, and `katex.min.js` + its CSS/fonts.
4. To keep typical (no-diagram, no-math) documents fast, the shell only injects the Mermaid/KaTeX `<script>` tags when the stripped body text contains a `` ```mermaid `` block or a `$`/`$$` math delimiter, detected via a cheap substring check before HTML assembly.
5. Load the HTML into a `WKWebView` hosted by the extension's own `NSViewController.view`, via `loadFileURL(_:allowingReadAccessTo:)`, passing the previewed document's containing directory as the read-access root so `marked`-rendered `<img src="./relative/path.png">` tags can resolve as `file://` URLs against that directory. The controller calls `preparePreviewOfFile`'s `completionHandler(nil)` once the web view's `WKNavigationDelegate.webView(_:didFinish:)` fires (or the internal timeout in Decision 6 is hit).
6. `marked.js` (with its GFM extension enabled: tables, task lists, footnotes) and `highlight.js` run client-side inside the web view to produce the final DOM; Mermaid/KaTeX (when injected) render their respective blocks after the initial parse.
- Alternative considered: pre-rendering everything to a static string in Swift (e.g. via a native Markdown parser) and only using the web view as a dumb HTML sink - rejected per the user's explicit choice of a JS-based renderer for full GFM/Mermaid/KaTeX fidelity without reimplementing those in Swift.

### 3. Vendored, pinned JS/CSS assets (no network, no package manager at build time)
`marked.js` (plus the `marked-footnote` extension - marked.js core has no GFM footnote support on its own, discovered during 4.1's end-to-end testing), `highlight.js`, `mermaid.js`, and `katex` (JS + CSS + font files) are downloaded once and committed into `Extension/Resources/vendor/` at pinned versions, with a `vendor/VERSIONS.md` recording exact version numbers and source URLs for future updates. A one-time `scripts/fetch-vendor-assets.sh` script automates (re-)downloading them into place for maintainers, but the build itself never fetches anything over the network - the committed files are the source of truth.
- Alternative considered: Swift Package Manager or CocoaPods JS-wrapper packages - rejected; none of these libraries are meaningfully "Swift packages," and pulling them via SPM would still ultimately just vendor a JS file, with more build-system complexity for no benefit.

### 4. App Sandbox and file access model
Both targets ship with `com.apple.security.app-sandbox = true`. The extension target additionally requires `com.apple.security.network.client` - **empirically confirmed necessary**, not optional: without it, `WKWebView`'s helper processes (`WebContent`, `GPU`, `Networking`) crash immediately on launch with `"Application does not have permission to communicate with network resources"` (errno=34), even when rendering purely local HTML with zero remote references. This is a WebKit platform requirement for those processes to bootstrap their own internal sandbox extensions, unrelated to whether the rendered page content ever issues a request. The offline-only requirement is instead enforced at the content level via a strict Content-Security-Policy (`default-src 'none'`, `script-src`/`style-src`/`img-src`/`font-src 'self'`) in the assembled HTML shell, which blocks any outbound request the page content could otherwise attempt regardless of the process-level entitlement. The host app target does not need this entitlement (it has no WKWebView).

The extension also relies on:
- The read-only sandbox extension macOS/QuickLookUIService grants automatically for the specific file being previewed.
- `allowingReadAccessTo:` on `loadFileURL` for the containing directory, to best-effort support relative image/link resolution.
This does not guarantee sibling-file (image) access always succeeds under every sandbox configuration (see Risks) - when it fails, the pipeline falls into the same "missing image" graceful-degradation path already required by `markdown-rendering-pipeline`, so no special-case error handling is needed for that failure mode.

### 5. Theming
A single bundled CSS file defines both light and dark palettes using `prefers-color-scheme`/`NSAppearance`-driven CSS custom properties, styled to resemble GitHub's default Markdown rendering (typography, code block backgrounds, table borders, blockquote left-border). The extension queries the host's effective appearance and sets the web view's `overrideColorScheme`-equivalent (via a `data-theme` attribute injected into the HTML `<html>` tag) rather than relying solely on the web content's own OS-level media query, so the theme is deterministic even if the web view's environment doesn't propagate the system appearance automatically.

### 6. Size/threshold limits
- **Truncation threshold**: 5 MB of raw file content. Markdown documents (notes, READMEs) are overwhelmingly small text files; 5 MB is generous headroom while still bounding worst-case read/parse/highlight time inside Quick Look's preview time budget. Files over this size are read only up to the threshold, with a visible "content truncated" notice appended to the rendered output.
- **Internal render timeout**: the controller enforces its own soft timeout (a few seconds, comfortably under Quick Look's system-level preview timeout) around HTML generation/web view load, after which it calls the completion handler with an error/fallback state rather than risking Quick Look killing the extension for being unresponsive.

### 7. Build/install/uninstall via shell scripts, with ad-hoc code signing
- `scripts/build.sh`: runs `xcodebuild -scheme "Markdown Quick Look" -configuration Release build`, capturing and printing failures verbatim on non-zero exit.
- `scripts/install.sh [install_dir]`: copies the built `.app` to `install_dir` (default `/Applications`), applies **ad-hoc code signing** (`codesign --force --deep -s -`) to both the host app and the embedded extension, then runs Launch Services (`lsregister -f`) and Quick Look cache (`qlmanage -r`, `qlmanage -r cache`) refreshes.
  - Ad-hoc signing (no Developer ID, no cost, no network) is a deliberate middle ground: it does not satisfy notarization/Gatekeeper for redistribution to other Macs (explicitly out of scope), but it gives the app a stable code identity so the App Sandbox and Launch Services behave consistently across rebuilds on the developer's own Mac, and reduces (though does not eliminate) local Gatekeeper friction versus a fully unsigned binary.
- `scripts/uninstall.sh [install_dir]`: removes the app bundle from `install_dir`, then rebuilds the Launch Services database (`lsregister -kill -r -domain local -domain system -domain user`) and resets the Quick Look cache so the extension stops being invoked.
- Alternative considered: a `Makefile` wrapping the same `xcodebuild`/`lsregister` calls - equivalent in substance; plain shell scripts under `scripts/` were chosen for simplicity and to avoid depending on `make` being installed/expected.

## Risks / Trade-offs

- [Risk] Sandbox may not always grant read access to sibling image files outside the exact previewed file, even with `allowingReadAccessTo:`. → Mitigation: treated as an expected, already-specified failure mode (broken-image placeholder), not a bug to chase; documented in README as a known limitation.
- [Risk] Bundling Mermaid + KaTeX (with fonts) meaningfully increases the extension bundle size (a few MB). → Mitigation: acceptable given the hard offline requirement; conditional `<script>` injection avoids paying the *parse/execute* cost for documents that don't use those features, even though the bytes are still on disk.
- [Risk] Quick Look kills extensions that take too long to reply. → Mitigation: internal timeout + file-size truncation bound worst-case latency well under the system limit.
- [Risk] Ad-hoc signing still triggers a one-time Gatekeeper prompt on first manual launch of the host app (not on Quick Look invocations of the extension itself). → Mitigation: `install.sh` prints an explicit note instructing the developer to right-click → Open the host app once if prompted; acceptable per the chosen "local unsigned build" distribution decision.
- [Risk] Launch Services/Quick Look caching is notoriously stale-prone; a rebuild+reinstall may not immediately reflect in Finder. → Mitigation: `install.sh`/`uninstall.sh` explicitly force-refresh both LS and the QL cache; README documents a manual fallback (log out/in, or `killall Finder`) if staleness persists.

## Migration Plan

Greenfield project - "migration" here means first-time setup on the developer's Mac:
1. Run `scripts/fetch-vendor-assets.sh` once (or use the assets already committed to the repo).
2. Run `scripts/build.sh`.
3. Run `scripts/install.sh` (optionally passing a custom install directory).
4. Quick Look any `.md` file to verify.
Rollback is `scripts/uninstall.sh`, which fully removes the app and resets Launch Services/Quick Look registration - no persistent state or data migration is involved.
