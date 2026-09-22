//
//  MarkdownQuickLookApp.swift
//  Markdown Quick Look
//
//  Host app for the MarkdownQuickLookExtension Quick Look preview extension.
//  This app has no meaningful functionality of its own - it exists so macOS
//  can discover, register, and (un)install the embedded QLPreviewingController
//  App Extension. See openspec/changes/add-markdown-quicklook-preview/design.md
//  - Decision 1.
//

import SwiftUI

@main
struct MarkdownQuickLookApp: App {
    var body: some Scene {
        WindowGroup {
            StatusView()
        }
        .windowResizability(.contentSize)
    }
}
