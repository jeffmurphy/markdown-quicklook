#!/usr/bin/env bash
#
# install.sh [install_dir]
#
# Installs the app built by scripts/build.sh (Release configuration)
# to install_dir (default /Applications), ad-hoc codesigns it
# (preserving each target's own entitlements), registers it with
# Launch Services, and resets the Quick Look cache so the extension
# becomes active for .md files without a reboot.
#
# See openspec/changes/add-markdown-quicklook-preview/specs/
# build-and-install-tooling/spec.md - Requirement: One-command install
# and registration.
#
# Usage: scripts/install.sh [install_dir]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="$REPO_ROOT/Markdown Quick Look.xcodeproj"
SCHEME="Markdown Quick Look"
CONFIGURATION="Release"
APP_NAME="Markdown Quick Look.app"
EXTENSION_NAME="MarkdownQuickLookExtension.appex"

INSTALL_DIR="${1:-/Applications}"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"

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

mkdir -p "$INSTALL_DIR"
INSTALLED_APP="$INSTALL_DIR/$APP_NAME"

echo "==> Installing to: $INSTALLED_APP"
rm -rf "$INSTALLED_APP"
cp -R "$BUILT_APP" "$INSTALLED_APP"

echo "==> Ad-hoc codesigning"
# Sign the embedded extension FIRST, with ITS OWN entitlements file, then
# the outer app, with ITS OWN entitlements file. A single "--deep" pass
# with no --entitlements flag would STRIP entitlements from both rather
# than preserving them - each bundle must be signed individually with
# its matching entitlements.
EXTENSION_PATH="$INSTALLED_APP/Contents/PlugIns/$EXTENSION_NAME"
codesign --force --sign - \
    --entitlements "$REPO_ROOT/Sources/MarkdownQuickLookExtension/MarkdownQuickLookExtension.entitlements" \
    "$EXTENSION_PATH"
codesign --force --sign - \
    --entitlements "$REPO_ROOT/Sources/MarkdownQuickLook/MarkdownQuickLook.entitlements" \
    "$INSTALLED_APP"

echo "==> Registering with Launch Services"
"$LSREGISTER" -f "$INSTALLED_APP"

echo "==> Resetting Quick Look cache"
qlmanage -r
qlmanage -r cache

echo "==> Installed and registered: $INSTALLED_APP"
echo "    Quick Look any .md file to verify."
