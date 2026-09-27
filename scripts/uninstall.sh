#!/usr/bin/env bash
#
# uninstall.sh [install_dir]
#
# Removes the app installed by scripts/install.sh from install_dir
# (default /Applications), rebuilds the Launch Services database, and
# resets the Quick Look cache so the extension is no longer invoked
# for .md files.
#
# See openspec/changes/add-markdown-quicklook-preview/specs/
# build-and-install-tooling/spec.md - Requirement: One-command
# uninstall.
#
# Usage: scripts/uninstall.sh [install_dir]

set -euo pipefail

APP_NAME="Markdown Quick Look.app"
INSTALL_DIR="${1:-/Applications}"
INSTALLED_APP="$INSTALL_DIR/$APP_NAME"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister"

if [ ! -d "$INSTALLED_APP" ]; then
    echo "==> Nothing installed at: $INSTALLED_APP (already uninstalled, or never installed)"
else
    echo "==> Removing: $INSTALLED_APP"
    rm -rf "$INSTALLED_APP"
fi

echo "==> Rebuilding the Launch Services database"
# Note: -kill was removed by Apple on newer macOS versions ("dangerous
# and no longer useful", per its own deprecation message, exiting
# non-zero if passed) - -r alone still forces a rebuild of the
# specified domains.
"$LSREGISTER" -r -domain local -domain system -domain user

echo "==> Resetting Quick Look cache"
qlmanage -r
qlmanage -r cache

echo "==> Uninstalled. .md files should revert to the default Quick Look text preview."
