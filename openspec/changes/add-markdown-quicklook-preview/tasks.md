## 1. Project Scaffolding

- [ ] 1.1 Create the Xcode project `Markdown Quick Look.xcodeproj` with a host app target (`Markdown Quick Look`, SwiftUI, macOS 13 deployment target) and verify it builds and launches a minimal status window in Xcode
- [ ] 1.2 Add the `MarkdownQuickLookExtension` App Extension target (extension point `com.apple.quicklook.preview`) embedded in the host app, and verify the host app's build product contains `Contents/PlugIns/MarkdownQuickLookExtension.appex`
- [ ] 1.3 Configure the extension's `Info.plist` to declare `.md` as a supported content type (`QLSupportedContentTypes` / `NSExtensionFileProviderDocumentGroup` as applicable) and verify via `qlmanage -m` or extension inspection that `.md` is listed as supported
- [ ] 1.4 Add App Sandbox entitlements files for both targets (`com.apple.security.app-sandbox = true`, no network entitlement) and verify the built binaries show sandbox enabled via `codesign -d --entitlements :- <binary>`
- [ ] 1.5 Set up `.gitignore` for Xcode build artifacts (`build/`, `DerivedData/`, `*.xcuserstate`) and verify a clean `git status` after a local build

## 2. Vendored Rendering Assets

- [ ] 2.1 Write `scripts/fetch-vendor-assets.sh` to download pinned versions of `marked.js`, `highlight.js` (common-language build), `mermaid.js`, and `katex` (JS+CSS+fonts) into `Extension/Resources/vendor/`, and verify running it populates all expected files
- [ ] 2.2 Commit the fetched vendor assets and a `vendor/VERSIONS.md` recording exact versions/source URLs, and verify the extension bundle includes them after a build (`ls` inside the built `.appex/Contents/Resources`)
- [ ] 2.3 Add the vendor assets as Copy-Bundle-Resources for the extension target and verify they appear in the built extension's `Resources` directory

## 3. Rendering Pipeline

- [ ] 3.1 Implement the HTML shell template (base document with theme CSS, `<script>` tags for `marked.js`/`highlight.js` always, and conditional tags for `mermaid.js`/`katex` only when the body contains those markers) and verify with a unit test that a plain-text document omits the Mermaid/KaTeX script tags while a doc with a ` ```mermaid ` block includes them
- [ ] 3.2 Implement the minimal front-matter parser (detect leading `---`-delimited block, parse flat `key: value` lines, strip it from the body) and verify unit tests for: front matter present, absent, and malformed (unterminated `---`)
- [ ] 3.3 Implement front-matter-to-metadata-table HTML rendering and verify a snapshot/unit test that key/value pairs appear as an HTML table separate from the body
- [ ] 3.4 Implement the light/dark theme CSS (GitHub-like styling for headings, code blocks, tables, blockquotes, task-list checkboxes) driven by an injected `data-theme` attribute, and verify visually in both appearances using `qlmanage -p` on a sample file with `NSApp` appearance toggled
- [ ] 3.5 Verify GFM features end-to-end (tables, task lists, footnotes) render correctly using a sample Markdown fixture file covering each, checked via `qlmanage -p sample.md` visual inspection
- [ ] 3.6 Verify fenced code block syntax highlighting for a known language and graceful plain-text fallback for an unknown/missing language, using sample fixtures
- [ ] 3.7 Verify Mermaid diagram rendering for a valid diagram fixture and graceful error fallback for an intentionally invalid Mermaid fixture
- [ ] 3.8 Verify KaTeX math rendering for a valid expression fixture and graceful raw-text fallback for an intentionally invalid math fixture

## 4. Quick Look Extension Controller

- [x] 4.1 Implement `QLPreviewingController.preparePreviewOfFile(at:completionHandler:)`: read file (capped at 100 KB - corrected from an original 5 MB assumption after empirical testing found marked.js's parse time scales quadratically and cannot handle multi-megabyte input at all, see design.md Decision 6 - appending a truncation notice beyond the cap), strip front matter, assemble HTML, and verify with a fixture file larger than the cap that the preview shows a truncation notice
- [ ] 4.2 Resolve relative images/links against the previewed document's directory in Swift (RelativeResourceResolver: base64-embed readable relative images, rewrite relative links to absolute file:// URLs) - corrected from an original loadFileURL(_:allowingReadAccessTo:) plan after empirical testing found WebKit rejects loading any file outside the granted directory, see design.md Decision 4 - and verify a fixture with a relative image (`./images/pic.png`) displays the image via `qlmanage -p`
- [ ] 4.3 Verify graceful handling of a missing relative image (broken-image placeholder, no crash) using a fixture referencing a non-existent image path
- [ ] 4.4 Implement an internal render/load timeout that calls the completion handler with a fallback/error state if exceeded, and verify via a deliberately slow/large fixture that the extension does not hang past the timeout
- [ ] 4.5 Implement error-state HTML/handling for empty files and unreadable files (permission-denied fixture), and verify each shows a styled empty state or clear error message rather than raw text or a crash
- [ ] 4.6 Verify the extension is not invoked for a non-`.md` file (e.g. `.txt`) by confirming Quick Look falls back to the default text preview for that file

## 5. Build, Install, Uninstall Tooling

- [ ] 5.1 Write `scripts/build.sh` running `xcodebuild -scheme "Markdown Quick Look" -configuration Release build`, printing build output on failure and exiting non-zero, and verify by intentionally breaking the build once and confirming the script surfaces the `xcodebuild` error and exits non-zero
- [ ] 5.2 Write `scripts/install.sh [install_dir]` that copies the built `.app` to `install_dir` (default `/Applications`), ad-hoc codesigns host app and extension (`codesign --force --deep -s -`), and refreshes Launch Services (`lsregister -f`) and the Quick Look cache (`qlmanage -r`, `qlmanage -r cache`); verify by running it after a successful build and confirming `.md` files show the rendered preview in Finder without a reboot
- [ ] 5.3 Verify `scripts/install.sh` run before any build fails with a clear, non-zero-exit error message directing the user to run `scripts/build.sh` first
- [ ] 5.4 Write `scripts/uninstall.sh [install_dir]` that removes the installed app and rebuilds the Launch Services database (`lsregister -kill -r -domain local -domain system -domain user`), and verify `.md` files revert to the default Quick Look text preview after running it
- [ ] 5.5 Verify App Sandbox: run `codesign -d --entitlements :- <installed extension binary>` and confirm `com.apple.security.app-sandbox` is `true` and no outbound-network entitlement is present

## 6. Documentation

- [ ] 6.1 Write `README.md` covering: what the extension does, macOS version requirement, first-time setup (`fetch-vendor-assets.sh` → `build.sh` → `install.sh`), the one-time Gatekeeper right-click-Open note for the ad-hoc-signed host app, and `uninstall.sh`, and verify all documented commands succeed when run in order on a clean checkout
- [ ] 6.2 Document known limitations (relative-image sandbox access is best-effort, 100 KB preview size cap, `.md`-only support) in `README.md`
