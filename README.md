# Markdown Quick Look

A macOS Quick Look extension for Markdown files. Select a `.md` file in Finder
and press Space: instead of raw Markdown source, you get a rendered HTML
preview - headings, GFM tables, task lists, footnotes, syntax-highlighted code
blocks, Mermaid diagrams, KaTeX math, and YAML front matter shown as a
metadata table. The theme follows the system's light/dark appearance.

Rendering is entirely offline. The extension never makes a network request -
all JS/CSS libraries (marked.js, marked-footnote, highlight.js, Mermaid,
KaTeX) are vendored and bundled into the extension itself.

See `openspec/changes/add-markdown-quicklook-preview/` for the full
proposal, design decisions, specs, and task history behind this project.

## Requirements

- macOS 13 (Ventura) or later.
- Xcode (the full IDE, not just the Command Line Tools) - needed to build a
  Quick Look App Extension target.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) to generate the Xcode
  project from `project.yml`:

  ```bash
  brew install xcodegen
  ```

## First-time setup

Run these in order from the repo root:

```bash
# 1. Generate/refresh the Xcode project from project.yml (project.yml is the
#    source of truth; the generated .xcodeproj is committed but regenerating
#    it confirms it's in sync).
xcodegen generate

# 2. Optional: re-fetch the vendored JS/CSS libraries. Not required on a
#    fresh checkout - the vendored assets are already committed under
#    Sources/MarkdownQuickLookExtension/Resources/vendor/ - but this is how
#    you refresh them (e.g. after bumping a pinned version in the script).
scripts/fetch-vendor-assets.sh

# 3. Build the host app + extension (Release configuration).
scripts/build.sh

# 4. Install to /Applications (or pass a different directory) and register
#    with Launch Services / Quick Look.
scripts/install.sh
```

### Gatekeeper note

The app is signed ad-hoc (`codesign -s -`), not with a paid Apple Developer
ID, and is not notarized - this project intentionally targets local personal
use, not distribution (see `design.md` Decision 7 for the reasoning). The
Quick Look extension itself works immediately after `install.sh`, with no
Gatekeeper prompt, since Finder invokes it directly. If you manually launch
the host app itself (**Markdown Quick Look.app** - it has no real UI beyond
a status message; you don't need to launch it for Quick Look to work),
macOS may show an "Apple could not verify this app is free of malware"
warning. If so, either:

- Right-click the app in Finder and choose **Open**, then confirm in the
  dialog that appears, or
- Go to **System Settings > Privacy & Security** and approve it there.

## Moving to another Mac (no admin rights needed)

If you want to install this on a machine where you don't have admin/sudo
(e.g. a second, non-admin laptop), you have two options, neither of which
needs elevated privileges:

- **Copy the repo and install to a directory you own**:
  `scripts/install.sh "$HOME/Applications"` instead of the default
  `/Applications`. Requires Xcode + XcodeGen on that machine too.
- **Build a drag-and-drop `.dmg` on this machine, transfer just that**:

  ```bash
  scripts/make-dmg.sh
  ```

  This produces `dist/Markdown Quick Look.dmg` - an ad-hoc-signed, ready-to-
  install disk image. Copy that one file to the other Mac (AirDrop, USB,
  etc.) - no need to clone the repo or install Xcode/XcodeGen there. Mount
  it and drag the app into `~/Applications` (or `/Applications`, if you do
  have admin rights there), then run, on that machine:

  ```bash
  /System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$HOME/Applications/Markdown Quick Look.app"
  qlmanage -r
  qlmanage -r cache
  ```

  (None of this needs `sudo`.)

## Distributing to coworkers/others (no Gatekeeper warning)

The ad-hoc `.dmg` from `scripts/make-dmg.sh` above still shows a Gatekeeper
"unidentified developer" warning for anyone you give it to - fine for your
own machines, not great for handing to coworkers. If you have a paid Apple
Developer account with a **Developer ID Application** certificate already
in your Keychain, use Developer ID signing + notarization instead:

```bash
# One-time setup (uses YOUR Apple ID - this script never sees your password):
xcrun notarytool store-credentials "notarytool-profile" \
  --apple-id "you@example.com" \
  --team-id "YOURTEAMID" \
  --password "an-app-specific-password"

# Then, any time you want a distributable build:
make notarize
# (equivalent to: scripts/build.sh && scripts/notarize.sh)
```

This signs with your real Developer ID (Hardened Runtime enabled), submits
to Apple's notary service, staples the ticket, and verifies Gatekeeper
acceptance - producing `dist/Markdown Quick Look (Notarized).dmg`, which
opens with **no warning at all** on any Mac.

## Command-line shortcuts (Makefile)

Once you have a checkout with Xcode/XcodeGen set up, `make help` lists
convenience targets wrapping the scripts above - `make install` rebuilds and
re-signs/installs in one step, `make dmg` / `make notarize` build the two
distributable package types, `make test` runs the unit test suite, etc.

## Usage

Select any `.md` file in Finder and press the Space bar.

## Uninstalling

```bash
scripts/uninstall.sh
```

Removes the installed app (from `/Applications` by default, or pass the same
directory you gave to `install.sh`), rebuilds the Launch Services database,
and resets the Quick Look cache. After this, `.md` files revert to the
system's default plain-text Quick Look preview.

## Known limitations

- **Only `.md` is recognized.** `.markdown`, `.mdown`, and `.mkd` are not
  registered content types for this extension.
- **100 KB preview size cap.** Files larger than 100 KB are truncated, with
  a visible notice appended to the preview. This is much smaller than an
  earlier 5 MB design target - empirical testing found that `marked.js`'s
  client-side parse time scales roughly quadratically with input size
  (measured: ~0.8s at 100 KB, ~19s at 500 KB, and multi-megabyte input never
  finished within a 30-second test), so a JS-based renderer running inside
  Quick Look's preview time budget cannot handle large documents at all.
  There is also a 5-second internal render timeout as a safety net, in case
  a particular document (e.g. many Mermaid diagrams) is unusually slow to
  render even under the size cap.
- **Relative image/link resolution is best-effort.** An image referenced
  by a relative path (e.g. `![alt](./images/pic.png)`) is read directly by
  the extension (not via a browser-level file load) and embedded inline as
  base64 if the read succeeds. This works in normal use, but exactly how
  macOS's App Sandbox scopes read access to files *other than* the one
  Quick Look explicitly hands to the extension isn't something Apple
  documents precisely, so it isn't unconditionally guaranteed for every
  file, in every circumstance. If the read fails for any reason, the image
  reference is left as-is and the browser shows its normal broken-image
  placeholder - no crash, no error dialog. Relative links are always
  rewritten to absolute `file://` URLs (no read required for that).
- **Ad-hoc signed, not notarized.** See the Gatekeeper note above. This is
  a deliberate scope decision for local personal use, not a limitation to
  be fixed - distributing this to other machines would need a paid Apple
  Developer ID and notarization, which is out of scope for this project.
