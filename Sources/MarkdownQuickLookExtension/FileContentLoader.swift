//
//  FileContentLoader.swift
//  MarkdownQuickLookExtension
//
//  Reads a previewed file's contents capped at a maximum byte size, per
//  openspec/changes/add-markdown-quicklook-preview/design.md - Decision 6
//  (truncation threshold). Distinguishes a genuinely empty (but
//  readable) file from one that couldn't be read at all (permissions,
//  I/O error) - see specs/markdown-quicklook-extension/spec.md -
//  Requirement: Graceful handling of malformed or unreadable input,
//  which requires different handling for each (empty: silent styled-
//  empty preview; unreadable: an explicit human-readable error
//  message).
//

import Foundation

struct FileContentLoadResult {
    let text: String
    let wasTruncated: Bool
}

enum FileContentLoader {

    /// Reads the file's contents, or throws the underlying error if the
    /// read fails (permissions, I/O, etc.) - callers distinguish this
    /// from an empty-but-successfully-read file by catching the error,
    /// rather than FileContentLoader silently mapping both cases to the
    /// same empty-string result.
    static func load(url: URL, maxBytes: Int) throws -> FileContentLoadResult {
        let data = try Data(contentsOf: url)

        if data.count > maxBytes {
            let text = String(decoding: data.prefix(maxBytes), as: UTF8.self)
            return FileContentLoadResult(text: text, wasTruncated: true)
        }

        let text = String(decoding: data, as: UTF8.self)
        return FileContentLoadResult(text: text, wasTruncated: false)
    }
}
