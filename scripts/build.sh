#!/usr/bin/env bash
#
# build.sh
#
# Builds Markdown Quick Look.app (host app + embedded
# MarkdownQuickLookExtension.appex) in Release configuration.
#
# See openspec/changes/add-markdown-quicklook-preview/specs/
# build-and-install-tooling/spec.md - Requirement: One-command local
# build.
#
# Usage: scripts/build.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT="$REPO_ROOT/Markdown Quick Look.xcodeproj"
SCHEME="Markdown Quick Look"
CONFIGURATION="Release"

echo "==> Building \"$SCHEME\" ($CONFIGURATION)"

BUILD_LOG="$(mktemp)"
trap 'rm -f "$BUILD_LOG"' EXIT

if ! xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" build \
    > "$BUILD_LOG" 2>&1; then
    echo "==> Build FAILED. xcodebuild output:" >&2
    echo "" >&2
    cat "$BUILD_LOG" >&2
    exit 1
fi

BUILT_PRODUCTS_DIR="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" \
    -showBuildSettings 2>/dev/null | awk -F'= ' '/ BUILT_PRODUCTS_DIR =/{print $2; exit}')"
FULL_PRODUCT_NAME="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIGURATION" \
    -showBuildSettings 2>/dev/null | awk -F'= ' '/ FULL_PRODUCT_NAME =/{print $2; exit}')"

APP_PATH="$BUILT_PRODUCTS_DIR/$FULL_PRODUCT_NAME"

if [ ! -d "$APP_PATH" ]; then
    echo "==> Build reported success but expected output not found at:" >&2
    echo "    $APP_PATH" >&2
    exit 1
fi

echo "==> Build succeeded."
echo "    $APP_PATH"
