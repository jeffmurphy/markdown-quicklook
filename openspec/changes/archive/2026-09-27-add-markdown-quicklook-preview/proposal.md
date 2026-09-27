## Why

macOS Quick Look (spacebar preview in Finder) renders `.md` files as raw plain text, forcing users to open an editor or browser tab just to read a formatted README or note. A Quick Look extension that renders Markdown to styled HTML lets users preview documentation directly from Finder with zero extra clicks.

## What Changes

- New Xcode project containing a host app (`Markdown Quick Look.app`) and an embedded `QLPreviewingController` App Extension (`.appex`) that macOS Quick Look launches for `.md` files.
- The extension converts Markdown source to themed HTML (GitHub-flavored styling, light/dark mode following system appearance) and renders it in a `WKWebView` inside the Quick Look panel.
- Rendering pipeline bundles `marked.js` (GFM parsing: tables, task lists, footnotes) and `highlight.js` (fenced code block syntax highlighting), plus Mermaid (diagram blocks) and KaTeX (math blocks) as bundled, offline JS/CSS assets - no network access at preview time.
- YAML front matter (`--- ... ---` at top of file) is parsed and rendered as a metadata table above the document body rather than as raw text.
- Relative image and link paths in the Markdown (e.g. `![x](./img/foo.png)`) resolve against the previewed file's own directory so local images render correctly.
- Local build/install/uninstall shell scripts to compile the project with `xcodebuild`, copy the built app to `/Applications` (or a user-specified location), and register it with Launch Services (`lsregister`) so Quick Look picks it up; includes a `qlmanage -r` / `killall Finder` refresh step.
- Targets macOS 13 (Ventura) and later. Local, unsigned development build only (no code signing/notarization in this change) - first launch requires the user to right-click → Open once, or approve in System Settings, to satisfy Gatekeeper.
- Only the `.md` extension is registered as a supported content type in this change (not `.markdown`, `.mdown`, etc.).

## Capabilities

### New Capabilities
- `markdown-quicklook-extension`: macOS Quick Look integration - host app + `QLPreviewingController` extension, `.md` UTI/content-type registration, invocation contract (given a file URL, produce a preview reply), sandboxing/entitlements, and error/fallback behavior for unreadable or malformed input.
- `markdown-rendering-pipeline`: The Markdown-to-HTML transformation behavior - GFM tables, fenced code syntax highlighting, task lists, footnotes, YAML front matter handling, relative image/link resolution, Mermaid diagrams, KaTeX math, and light/dark theme selection.
- `build-and-install-tooling`: Local developer-facing build, install, and uninstall scripts for compiling the project and registering/unregistering the extension with Launch Services on the developer's own Mac.

### Modified Capabilities
- (none - this is a new repository with no existing specs)

## Impact

- **New repo structure**: Xcode project/workspace, host app target, App Extension target, bundled third-party JS/CSS assets (marked, highlight.js, mermaid, KaTeX - vendored, not fetched at runtime), shell scripts under `scripts/`.
- **System integration**: Registers a Launch Services content-type handler for `.md` on the developer's Mac; affects how Finder/Quick Look behaves for Markdown files system-wide on that machine until uninstalled.
- **No backend/network dependency**: all rendering is local and offline.
- **Out of scope for this change**: code signing/notarization for distribution, non-`.md` extensions, App Store distribution, Windows/Linux support.
