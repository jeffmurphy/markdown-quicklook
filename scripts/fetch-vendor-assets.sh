#!/usr/bin/env bash
#
# fetch-vendor-assets.sh
#
# Downloads pinned versions of the third-party JS/CSS libraries the
# MarkdownQuickLookExtension rendering pipeline bundles offline (marked.js,
# highlight.js, Mermaid, KaTeX) into Sources/MarkdownQuickLookExtension/
# Resources/vendor/. This is a one-time/occasional maintainer script - the
# Xcode build itself never fetches anything over the network; the files
# committed to the repo are the source of truth.
#
# See openspec/changes/add-markdown-quicklook-preview/design.md - Decision 3.
#
# Usage: scripts/fetch-vendor-assets.sh
#
# Safe to re-run: each run re-downloads the same pinned versions and
# overwrites the vendor directory with identical content.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VENDOR_DIR="$REPO_ROOT/Sources/MarkdownQuickLookExtension/Resources/vendor"

# Pinned versions - update deliberately, not automatically.
MARKED_VERSION="18.0.14"
HIGHLIGHTJS_VERSION="11.11.2"
MERMAID_VERSION="12.0.0"
KATEX_VERSION="0.18.7"

MARKED_URL="https://cdn.jsdelivr.net/npm/marked@${MARKED_VERSION}/lib/marked.umd.js"
HIGHLIGHTJS_JS_URL="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/${HIGHLIGHTJS_VERSION}/highlight.min.js"
HIGHLIGHTJS_LIGHT_CSS_URL="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/${HIGHLIGHTJS_VERSION}/styles/github.min.css"
HIGHLIGHTJS_DARK_CSS_URL="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/${HIGHLIGHTJS_VERSION}/styles/github-dark.min.css"
MERMAID_URL="https://cdn.jsdelivr.net/npm/mermaid@${MERMAID_VERSION}/dist/mermaid.min.js"
KATEX_TARBALL_URL="https://github.com/KaTeX/KaTeX/releases/download/v${KATEX_VERSION}/katex.tar.gz"

echo "==> Fetching vendor assets into: $VENDOR_DIR"
mkdir -p "$VENDOR_DIR/marked" "$VENDOR_DIR/highlight/styles" "$VENDOR_DIR/mermaid" "$VENDOR_DIR/katex"

fetch() {
  local url="$1"
  local dest="$2"
  curl -fsSL "$url" -o "$dest"
}

echo "--> marked.js ${MARKED_VERSION}"
fetch "$MARKED_URL" "$VENDOR_DIR/marked/marked.umd.js"

echo "--> highlight.js ${HIGHLIGHTJS_VERSION} (common-language bundle + github light/dark themes)"
fetch "$HIGHLIGHTJS_JS_URL" "$VENDOR_DIR/highlight/highlight.min.js"
fetch "$HIGHLIGHTJS_LIGHT_CSS_URL" "$VENDOR_DIR/highlight/styles/github.min.css"
fetch "$HIGHLIGHTJS_DARK_CSS_URL" "$VENDOR_DIR/highlight/styles/github-dark.min.css"

echo "--> mermaid ${MERMAID_VERSION}"
fetch "$MERMAID_URL" "$VENDOR_DIR/mermaid/mermaid.min.js"

echo "--> katex ${KATEX_VERSION} (js + css + fonts)"
KATEX_TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$KATEX_TMP_DIR"' EXIT
fetch "$KATEX_TARBALL_URL" "$KATEX_TMP_DIR/katex.tar.gz"
tar -xzf "$KATEX_TMP_DIR/katex.tar.gz" -C "$KATEX_TMP_DIR"
cp "$KATEX_TMP_DIR/katex/katex.min.js" "$VENDOR_DIR/katex/katex.min.js"
cp "$KATEX_TMP_DIR/katex/katex.min.css" "$VENDOR_DIR/katex/katex.min.css"
mkdir -p "$VENDOR_DIR/katex/contrib"
cp "$KATEX_TMP_DIR/katex/contrib/auto-render.min.js" "$VENDOR_DIR/katex/contrib/auto-render.min.js"
rm -rf "$VENDOR_DIR/katex/fonts"
cp -R "$KATEX_TMP_DIR/katex/fonts" "$VENDOR_DIR/katex/fonts"

echo ""
echo "==> Done. Fetched versions:"
echo "    marked.js:     ${MARKED_VERSION}"
echo "    highlight.js:  ${HIGHLIGHTJS_VERSION}"
echo "    mermaid:       ${MERMAID_VERSION}"
echo "    katex:         ${KATEX_VERSION}"
echo ""
echo "Vendor directory contents:"
find "$VENDOR_DIR" -type f | sed "s|$REPO_ROOT/||" | sort
