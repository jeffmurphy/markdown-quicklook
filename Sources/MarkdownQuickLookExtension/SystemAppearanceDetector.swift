//
//  SystemAppearanceDetector.swift
//  MarkdownQuickLookExtension
//
//  Maps the current macOS system appearance to an HTMLShellBuilder.Theme,
//  so the rendered HTML's data-theme attribute is set deterministically
//  by us rather than relying solely on the web view's own
//  prefers-color-scheme propagation. See design.md Decision 5.
//

import Cocoa

enum SystemAppearanceDetector {

    /// The theme matching the app's current effective appearance.
    static func currentTheme() -> HTMLShellBuilder.Theme {
        theme(for: NSApp.effectiveAppearance)
    }

    /// Pure mapping from an `NSAppearance` to our `Theme`, extracted so it
    /// can be unit tested with an explicit appearance rather than
    /// depending on `NSApp`'s live state.
    static func theme(for appearance: NSAppearance) -> HTMLShellBuilder.Theme {
        let matched = appearance.bestMatch(from: [.darkAqua, .aqua])
        return matched == .darkAqua ? .dark : .light
    }
}
