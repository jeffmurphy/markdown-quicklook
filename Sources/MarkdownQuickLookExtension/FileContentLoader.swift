//
//  FileContentLoader.swift
//  MarkdownQuickLookExtension
//
//  Reads a previewed file's contents capped at a maximum byte size, per
//  openspec/changes/add-markdown-quicklook-preview/design.md - Decision 6
//  (5MB truncation threshold). Never throws - an unreadable file simply
//  yields empty, non-truncated content (the user-facing error state for
//  that case is implemented in task 4.5).
//

import Foundation

struct FileContentLoadResult {
    let text: String
    let wasTruncated: Bool
}

enum FileContentLoader {

    static func load(url: URL, maxBytes: Int) -> FileContentLoadResult {
        guard let data = try? Data(contentsOf: url) else {
            return FileContentLoadResult(text: "", wasTruncated: false)
        }

        if data.count > maxBytes {
            let text = String(decoding: data.prefix(maxBytes), as: UTF8.self)
            return FileContentLoadResult(text: text, wasTruncated: true)
        }

        let text = String(decoding: data, as: UTF8.self)
        return FileContentLoadResult(text: text, wasTruncated: false)
    }
}
