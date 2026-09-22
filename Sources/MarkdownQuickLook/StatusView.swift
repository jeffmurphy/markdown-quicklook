//
//  StatusView.swift
//  Markdown Quick Look
//
//  Minimal status window shown when the host app is launched directly.
//  See openspec/changes/add-markdown-quicklook-preview/design.md - Decision 1.
//

import SwiftUI

struct StatusView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Markdown Quick Look")
                .font(.title2)
                .bold()

            Text("Extension installed - Quick Look any .md file to preview it.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(32)
        .frame(width: 360)
    }
}

#Preview {
    StatusView()
}
