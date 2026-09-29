# Makefile - convenience wrappers around scripts/*.sh
#
# Run `make help` to list targets.

.PHONY: help build test resign install uninstall dmg notarize clean

INSTALL_DIR ?= /Applications
NOTARY_PROFILE ?= notarytool-profile

help:
	@echo "Targets:"
	@echo "  make build              - scripts/build.sh (Release build only)"
	@echo "  make test               - run the unit test suite (Debug)"
	@echo "  make resign             - re-sign + install the CURRENT build (no rebuild) - scripts/install.sh"
	@echo "  make install            - rebuild AND resign/install in one step (build + resign)"
	@echo "  make uninstall          - scripts/uninstall.sh"
	@echo "  make dmg                - rebuild + package an ad-hoc-signed dist/*.dmg (personal use)"
	@echo "  make notarize           - rebuild + sign with Developer ID + notarize + staple (for distributing to others)"
	@echo "  make clean              - remove dist/ and clean Xcode build artifacts"
	@echo ""
	@echo "Variables (override with VAR=value):"
	@echo "  INSTALL_DIR             - where 'resign'/'install'/'uninstall' target (default: /Applications)"
	@echo "  NOTARY_PROFILE          - xcrun notarytool keychain profile name (default: notarytool-profile)"

build:
	./scripts/build.sh

test:
	xcodebuild -project "Markdown Quick Look.xcodeproj" -scheme "Markdown Quick Look" -configuration Debug test

resign:
	./scripts/install.sh "$(INSTALL_DIR)"

install: build resign

uninstall:
	./scripts/uninstall.sh "$(INSTALL_DIR)"

dmg: build
	./scripts/make-dmg.sh

notarize: build
	./scripts/notarize.sh "$(NOTARY_PROFILE)"

clean:
	rm -rf dist
	xcodebuild -project "Markdown Quick Look.xcodeproj" -scheme "Markdown Quick Look" clean
