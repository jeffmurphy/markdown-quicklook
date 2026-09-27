#!/usr/bin/env bash
#
# make-dmg.sh
#
# Packages the app built by scripts/build.sh (Release configuration)
# into a distributable, drag-and-drop .dmg. Ad-hoc codesigns a STAGING
# COPY (never mutates the DerivedData build product itself), verifies
# the signature, then creates a compressed disk image containing the
# .app plus an Applications shortcut for the familiar drag-to-install
# UX. Useful for moving the app to another Mac (e.g. via AirDrop/USB)
# without needing to clone the repo + Xcode + XcodeGen there too - the
# recipient just double-clicks the .dmg and drags the app into their
# own ~/Applications (no admin/sudo required for that, or for anything
# this script itself does).
#
# Usage: scripts/make-dmg.sh
#
# Output: dist/Markdown Quick Look.dmg (dist/ is gitignored - this is
# a build artifact, not committed source).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="$REPO_ROOT/Markdown Quick Look.xcodeproj"
SCHEME="Markdown Quick Look"
CONFIGURATION="Release"
APP_NAME="Markdown Quick Look.app"
EXTENSION_NAME="MarkdownQuickLookExtension.appex"
DIST_DIR="$REPO_ROOT/dist"
DMG_PATH="$DIST_DIR/Markdown Quick Look.dmg"
VOLUME_NAME="Markdown Quick Look"

BUILT_PRODUCTS_DIR="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" \
    -showBuildSettings 2>/dev/null | awk -F'= ' '/ BUILT_PRODUCTS_DIR =/{print $2; exit}')"
BUILT_APP="$BUILT_PRODUCTS_DIR/$APP_NAME"

if [ ! -d "$BUILT_APP" ]; then
    echo "==> No built app found at:" >&2
    echo "    $BUILT_APP" >&2
    echo "" >&2
    echo "Run scripts/build.sh first, then re-run this script." >&2
    exit 1
fi

STAGING_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGING_DIR"' EXIT

echo "==> Staging a copy of the built app for signing"
STAGED_APP="$STAGING_DIR/$APP_NAME"
cp -R "$BUILT_APP" "$STAGED_APP"

echo "==> Ad-hoc codesigning (staged copy only - DerivedData build product is untouched)"
# Sign the embedded extension FIRST with ITS OWN entitlements, then the
# outer app with ITS OWN entitlements - same pattern as install.sh. A
# single "--deep" pass with no --entitlements flag would strip
# entitlements from both rather than preserving them.
codesign --force --sign - \
    --entitlements "$REPO_ROOT/Sources/MarkdownQuickLookExtension/MarkdownQuickLookExtension.entitlements" \
    "$STAGED_APP/Contents/PlugIns/$EXTENSION_NAME"
codesign --force --sign - \
    --entitlements "$REPO_ROOT/Sources/MarkdownQuickLook/MarkdownQuickLook.entitlements" \
    "$STAGED_APP"

echo "==> Verifying signature"
codesign --verify --deep --strict "$STAGED_APP"

echo "==> Building disk image"
mkdir -p "$DIST_DIR"
rm -f "$DMG_PATH"
ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
    -volname "$VOLUME_NAME" \
    -srcfolder "$STAGING_DIR" \
    -fs HFS+ \
    -format UDZO \
    -ov \
    "$DMG_PATH" \
    > /dev/null

echo "==> Created: $DMG_PATH"
echo "    Double-click to mount, then drag \"$APP_NAME\" into ~/Applications"
echo "    (or /Applications, if you have admin rights there)."
