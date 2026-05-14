// MarkdownSectionParser.swift – reusable H2 section extraction for vault notes

import Foundation

enum MarkdownSectionParser {
    static func section(named title: String, in markdown: String) -> String? {
        let lines = markdown.components(separatedBy: .newlines)
        let wanted = normalized(title)
        var body: [String] = []
        var isCapturing = false

        for rawLine in lines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("## ") {
                if isCapturing { break }
                let heading = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespacesAndNewlines)
                if normalized(heading) == wanted {
                    isCapturing = true
                }
                continue
            }

            if isCapturing {
                if trimmed == "---" { break }
                body.append(rawLine)
            }
        }

        let result = body.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? nil : result
    }

    static func removingFrontmatter(from markdown: String) -> String {
        var lines = markdown.components(separatedBy: .newlines)
        guard lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---" else { return markdown }

        for index in lines.indices.dropFirst() {
            if lines[index].trimmingCharacters(in: .whitespacesAndNewlines) == "---" {
                lines.removeSubrange(...index)
                return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        return markdown
    }

    private static func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
