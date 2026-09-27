//
//  RelativeResourceResolver.swift
//  MarkdownQuickLookExtension
//
//  Best-effort resolution of relative image/link references against the
//  previewed document's own directory - done entirely in Swift, never
//  by asking WebKit to load anything outside its own bundle. See
//  openspec/changes/add-markdown-quicklook-preview/design.md - Decision 4.
//
//  Images: successfully-read files are rewritten to inline base64
//  `data:` URIs. Unreadable/missing files are left untouched, so the
//  browser's native broken-image handling takes over - this directly
//  satisfies the "missing image degrades gracefully" requirement as a
//  side effect, with no separate error-handling code needed.
//
//  Links: rewritten to absolute file:// URLs (string construction only,
//  no read required).
//
//  Both are regex-based, best-effort passes over the raw Markdown
//  source - not a full Markdown parse - matching the same "cheap,
//  acceptable false positives/negatives" philosophy as
//  RenderingFeatureDetector.
//

import Foundation

enum RelativeResourceResolver {

    /// - Parameters:
    ///   - markdownSource: Raw Markdown body (front matter already
    ///     stripped).
    ///   - documentDirectory: The directory containing the previewed
    ///     Markdown file, against which relative references resolve.
    static func resolve(markdownSource: String, documentDirectory: URL) -> String {
        var result = resolveImages(in: markdownSource, documentDirectory: documentDirectory)
        result = resolveLinks(in: result, documentDirectory: documentDirectory)
        return result
    }

    // MARK: - Images

    private static let imagePattern = #"!\[([^\]]*)\]\(([^)\s]+)([^)]*)\)"#

    private static func resolveImages(in markdown: String, documentDirectory: URL) -> String {
        replaceMatches(of: imagePattern, in: markdown) { groups in
            let alt = groups[1]
            let target = groups[2]
            let rest = groups[3]

            guard isRelativeReference(target) else {
                return nil
            }
            guard let data = readFile(target, relativeTo: documentDirectory) else {
                // Leave untouched - browser's native broken-image
                // handling takes over.
                return nil
            }
            let mimeType = mimeType(forPathExtension: (target as NSString).pathExtension)
            let base64 = data.base64EncodedString()
            return "![\(alt)](data:\(mimeType);base64,\(base64)\(rest))"
        }
    }

    // MARK: - Links (not images - negative lookbehind excludes `!`)

    private static let linkPattern = #"(?<!!)\[([^\]]*)\]\(([^)\s]+)([^)]*)\)"#

    private static func resolveLinks(in markdown: String, documentDirectory: URL) -> String {
        replaceMatches(of: linkPattern, in: markdown) { groups in
            let text = groups[1]
            let target = groups[2]
            let rest = groups[3]

            guard isRelativeReference(target) else {
                return nil
            }
            let resolvedURL = documentDirectory.appendingPathComponent(target).standardizedFileURL
            return "[\(text)](\(resolvedURL.absoluteString)\(rest))"
        }
    }

    // MARK: - Helpers

    /// A reference is "relative" (eligible for resolution) if it has no
    /// URL scheme (`http://`, `data:`, etc.), doesn't start with `/`
    /// (absolute path), and isn't anchor-only (`#section`).
    private static func isRelativeReference(_ target: String) -> Bool {
        if target.hasPrefix("#") {
            return false
        }
        if target.hasPrefix("/") {
            return false
        }
        if target.range(of: #"^[A-Za-z][A-Za-z0-9+.-]*:"#, options: .regularExpression) != nil {
            return false
        }
        return true
    }

    private static func readFile(_ relativePath: String, relativeTo documentDirectory: URL) -> Data? {
        let resolvedURL = documentDirectory.appendingPathComponent(relativePath).standardizedFileURL
        return try? Data(contentsOf: resolvedURL)
    }

    private static func mimeType(forPathExtension ext: String) -> String {
        switch ext.lowercased() {
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "webp": return "image/webp"
        case "bmp": return "image/bmp"
        default: return "application/octet-stream"
        }
    }

    /// Replaces every regex match in `text` whose transform returns a
    /// non-nil replacement string; matches where the transform returns
    /// nil are left completely untouched (including their original
    /// exact text).
    private static func replaceMatches(
        of pattern: String,
        in text: String,
        transform: ([String]) -> String?
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return text
        }
        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        var result = ""
        var lastEnd = 0
        for match in matches {
            let groups: [String] = (0..<match.numberOfRanges).map { i in
                let range = match.range(at: i)
                return range.location == NSNotFound ? "" : nsText.substring(with: range)
            }
            let fullRange = match.range(at: 0)
            result += nsText.substring(with: NSRange(location: lastEnd, length: fullRange.location - lastEnd))
            if let replacement = transform(groups) {
                result += replacement
            } else {
                result += groups[0]
            }
            lastEnd = fullRange.location + fullRange.length
        }
        result += nsText.substring(from: lastEnd)
        return result
    }
}
