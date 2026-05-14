// FrontmatterParser.swift – lightweight YAML-frontmatter subset parser

import Foundation

struct NoteFrontmatter: Sendable, Equatable {
    let updated: String?
    let status: String?
    let type: String?

    var hasValues: Bool {
        updated != nil || status != nil || type != nil
    }
}

enum FrontmatterParser {
    static func parse(_ content: String) -> NoteFrontmatter? {
        guard content.hasPrefix("---") else { return nil }

        let lines = content.components(separatedBy: .newlines)
        guard lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) == "---" else {
            return nil
        }

        var values: [String: String] = [:]
        var foundClosingDelimiter = false

        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed == "---" {
                foundClosingDelimiter = true
                break
            }

            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard ["updated", "status", "type"].contains(key) else { continue }

            let rawValue = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = stripWrappingQuotes(rawValue)
            if !value.isEmpty {
                values[key] = value.lowercased()
            }
        }

        guard foundClosingDelimiter else { return nil }

        return NoteFrontmatter(
            updated: values["updated"],
            status: values["status"],
            type: values["type"]
        )
    }

    private static func stripWrappingQuotes(_ value: String) -> String {
        guard value.count >= 2 else { return value }
        let first = value.first
        let last = value.last
        if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
            return String(value.dropFirst().dropLast())
        }
        return value
    }
}
