#!/usr/bin/env bash
#
# notarize.sh [notarytool_profile]
#
# Signs the Release build with a real Developer ID Application
# certificate (auto-discovered from your Keychain - not ad-hoc),
# packages it into a .dmg, submits it to Apple's notary service, and
# staples the resulting ticket. Produces a .dmg that opens with NO
# Gatekeeper warning on any Mac - unlike scripts/make-dmg.sh (ad-hoc,
# personal-use-only), this is meant for distributing to other people.
#
# One-time setup required before this script works (do this yourself -
# it needs your own Apple ID/credentials, which this script never
# touches or stores):
#
#   1. A "Developer ID Application" certificate must already be in
#      your Keychain. If `security find-identity -v -p codesigning`
#      doesn't show one, get it via Xcode -> Settings -> Accounts ->
#      select your team -> Manage Certificates -> "+" -> Developer ID
#      Application.
#
#   2. Store notarization credentials ONCE, in your own Keychain, under
#      a named profile (default name below is "notarytool-profile"):
#
#        xcrun notarytool store-credentials "notarytool-profile" \
#          --apple-id "you@example.com" \
#          --team-id "YOURTEAMID" \
#          --password "an-app-specific-password"
#
#      (Generate an app-specific password at https://appleid.apple.com
#      if you're not using an App Store Connect API key instead - see
#      `xcrun notarytool store-credentials --help` for the API-key form.)
#      This stores credentials securely in YOUR Keychain; this script
#      only ever references the profile NAME, never a password.
#
# Usage: scripts/notarize.sh [notarytool_profile]
#   notarytool_profile defaults to "notarytool-profile"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="$REPO_ROOT/Markdown Quick Look.xcodeproj"
SCHEME="Markdown Quick Look"
CONFIGURATION="Release"
APP_NAME="Markdown Quick Look.app"
EXTENSION_NAME="MarkdownQuickLookExtension.appex"
DIST_DIR="$REPO_ROOT/dist"
DMG_PATH="$DIST_DIR/Markdown Quick Look (Notarized).dmg"
VOLUME_NAME="Markdown Quick Look"

NOTARY_PROFILE="${1:-notarytool-profile}"

echo "==> Looking for a Developer ID Application certificate"
IDENTITY="$(security find-identity -v -p codesigning \
    | grep "Developer ID Application" \
    | head -1 \
    | sed -E 's/.*"(.*)"/\1/' || true)"

if [ -z "$IDENTITY" ]; then
    echo "==> No 'Developer ID Application' certificate found in your Keychain." >&2
    echo "    Get one via Xcode -> Settings -> Accounts -> Manage Certificates -> '+'." >&2
    exit 1
fi
echo "    Using identity: $IDENTITY"

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

echo "==> Signing with Developer ID (Hardened Runtime enabled - required for notarization)"
# Sign the embedded extension FIRST with ITS OWN entitlements, then the
# outer app with ITS OWN entitlements - same pattern as install.sh/
# make-dmg.sh, just with a real identity + --options runtime instead of
# ad-hoc "-".
codesign --force --sign "$IDENTITY" --options runtime \
    --entitlements "$REPO_ROOT/Sources/MarkdownQuickLookExtension/MarkdownQuickLookExtension.entitlements" \
    "$STAGED_APP/Contents/PlugIns/$EXTENSION_NAME"
codesign --force --sign "$IDENTITY" --options runtime \
    --entitlements "$REPO_ROOT/Sources/MarkdownQuickLook/MarkdownQuickLook.entitlements" \
    "$STAGED_APP"

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$STAGED_APP"

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

echo "==> Signing the disk image itself"
# Gatekeeper's assessment of a downloaded file checks the CONTAINER's
# own signature, not just what's inside it - notarization tickets get
# attached to (and checked against) this outer signature. Signing only
# the .app inside and leaving the .dmg itself unsigned produces a
# notarized-and-stapled DMG that Apple still accepts, but that
# `spctl -t open` on the DMG itself reports as "rejected, source=no
# usable signature" - found via real testing.
codesign --force --sign "$IDENTITY" "$DMG_PATH"

echo "==> Submitting to Apple's notary service (this can take a few minutes)"
xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling notarization ticket"
xcrun stapler staple "$DMG_PATH"

echo "==> Verifying Gatekeeper acceptance"
spctl -a -t open --context context:primary-signature -v "$DMG_PATH"

echo "==> Done: $DMG_PATH"
echo "    This .dmg is notarized - it will open with no Gatekeeper warning"
echo "    for anyone, on any Mac."
