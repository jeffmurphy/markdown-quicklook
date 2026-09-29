#!/usr/bin/env bash
#
# generate-appicons.sh
#
# Regenerates the macOS AppIcon.appiconset PNGs for the "Markdown Quick
# Look" host app from a single square source image, using sips (no
# external dependencies).
#
# Usage: scripts/generate-appicons.sh [source_image]
#   source_image defaults to design/markdownquicklookicon.png in the repo.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SRC="${1:-$REPO_ROOT/design/markdownquicklookicon.png}"
DEST="$REPO_ROOT/Sources/MarkdownQuickLook/Assets.xcassets/AppIcon.appiconset"

if [ ! -f "$SRC" ]; then
    echo "==> Source icon not found: $SRC" >&2
    exit 1
fi

mkdir -p "$DEST"

echo "==> Generating AppIcon.appiconset from $SRC"

sips -z 16 16     "$SRC" --out "$DEST/icon_16x16.png"       > /dev/null
sips -z 32 32     "$SRC" --out "$DEST/icon_16x16@2x.png"    > /dev/null
sips -z 32 32     "$SRC" --out "$DEST/icon_32x32.png"       > /dev/null
sips -z 64 64     "$SRC" --out "$DEST/icon_32x32@2x.png"    > /dev/null
sips -z 128 128   "$SRC" --out "$DEST/icon_128x128.png"     > /dev/null
sips -z 256 256   "$SRC" --out "$DEST/icon_128x128@2x.png"  > /dev/null
sips -z 256 256   "$SRC" --out "$DEST/icon_256x256.png"     > /dev/null
sips -z 512 512   "$SRC" --out "$DEST/icon_256x256@2x.png"  > /dev/null
sips -z 512 512   "$SRC" --out "$DEST/icon_512x512.png"     > /dev/null
sips -z 1024 1024 "$SRC" --out "$DEST/icon_512x512@2x.png"  > /dev/null

echo "==> AppIcon.appiconset written to $DEST"
