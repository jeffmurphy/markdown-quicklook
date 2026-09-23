//
//  FrontMatterParser.swift
//  MarkdownQuickLookExtension
//
//  Minimal, line-based parser for a leading YAML front matter block
//  (--- ... ---) at the very start of a Markdown file. Intentionally does
//  NOT depend on a full YAML library - only flat `key: value` pairs are
//  parsed; non-scalar/nested/list values are captured as literal raw text
//  appended to their parent key rather than deeply interpreted. See
//  openspec/changes/add-markdown-quicklook-preview/design.md - Decision 2
//  step 2, and specs/markdown-rendering-pipeline/spec.md - Requirement:
//  YAML front matter handling.
//

import Foundation

struct FrontMatterParseResult {
    let metadata: [(key: String, value: String)]
    let body: String
}

enum FrontMatterParser {

    private static let delimiter = "---"

    /// Detects a leading `---`-delimited block, parses it into flat
    /// key/value pairs, and returns the remaining body with that block
    /// removed. If the file doesn't start with `---`, or the block is
    /// never closed (malformed/unterminated), returns empty metadata and
    /// the entire original source as the body, unchanged - never throws
    /// or crashes.
    static func parse(_ source: String) -> FrontMatterParseResult {
        let lines = source.components(separatedBy: "\n")

        guard let firstLine = lines.first,
              firstLine.trimmingCharacters(in: .whitespaces) == delimiter else {
            return FrontMatterParseResult(metadata: [], body: source)
        }

        guard lines.count > 1 else {
            // Just a lone "---" and nothing else - no closing delimiter
            // possible.
            return FrontMatterParseResult(metadata: [], body: source)
        }

        var closingIndex: Int?
        for index in 1..<lines.count {
            if lines[index].trimmingCharacters(in: .whitespaces) == delimiter {
                closingIndex = index
                break
            }
        }

        guard let closingIndex else {
            // Unterminated front matter block - degrade gracefully to
            // treating the whole file as body with no metadata.
            return FrontMatterParseResult(metadata: [], body: source)
        }

        let frontMatterLines = Array(lines[1..<closingIndex])
        let bodyLines = Array(lines[(closingIndex + 1)...])
        let body = bodyLines.joined(separator: "\n")

        return FrontMatterParseResult(metadata: parseKeyValueLines(frontMatterLines), body: body)
    }

    /// Parses flat `key: value` lines. A line that doesn't match that
    /// shape (e.g. a YAML list item or a nested mapping's continuation
    /// line, both conventionally indented) is appended as raw text to the
    /// value of the most recently seen key, rather than being deeply
    /// parsed. Leading continuation content with no prior key is ignored
    /// rather than crashing.
    private static func parseKeyValueLines(_ lines: [String]) -> [(key: String, value: String)] {
        var result: [(key: String, value: String)] = []

        for rawLine in lines {
            if rawLine.trimmingCharacters(in: .whitespaces).isEmpty {
                continue
            }

            if let parsed = splitKeyValue(rawLine) {
                result.append(parsed)
            } else if !result.isEmpty {
                let lastIndex = result.count - 1
                let previous = result[lastIndex]
                let trimmedLine = rawLine.trimmingCharacters(in: .whitespaces)
                let appendedValue = previous.value.isEmpty
                    ? trimmedLine
                    : previous.value + " " + trimmedLine
                result[lastIndex] = (key: previous.key, value: appendedValue)
            }
        }

        return result
    }

    /// Splits a line into `(key, value)` if it looks like a top-level
    /// `key: value` pair. Indented lines (leading space/tab) are treated
    /// as nested/continuation content, not a new key, matching YAML's
    /// own indentation-based nesting convention.
    private static func splitKeyValue(_ line: String) -> (key: String, value: String)? {
        guard !line.hasPrefix(" "), !line.hasPrefix("\t") else {
            return nil
        }
        guard let colonIndex = line.firstIndex(of: ":") else {
            return nil
        }
        let key = String(line[line.startIndex..<colonIndex]).trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else {
            return nil
        }
        let valueStart = line.index(after: colonIndex)
        let value = String(line[valueStart...]).trimmingCharacters(in: .whitespaces)
        return (key: key, value: value)
    }
}
