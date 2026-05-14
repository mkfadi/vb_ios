// Note.swift – Datenmodell für eine einzelne Markdown-Notiz

import Foundation

struct Note: Identifiable, Sendable {

    // Identifiable: Dateipfad dient als eindeutige ID
    var id: String { path }

    /// Relativer Pfad im GitHub-Repo, z.B. "Folder/Idee.md"
    let path: String

    /// Anzeigename ohne Pfad und .md-Endung
    let name: String

    /// Vollständiger Markdown-Inhalt der Notiz
    var content: String

    /// GitHub-SHA der Datei – wird für PUT /contents benötigt
    var sha: String

    /// Alle [[wikilinks]] die in dieser Notiz gefunden wurden (nur der Zielname)
    var links: [String]

    /// Optionales YAML-Frontmatter am Anfang der Markdown-Datei
    var frontmatter: NoteFrontmatter?

    // Extrahiert den Dateinamen aus einem Pfad und entfernt die .md-Endung
    static func extractName(from path: String) -> String {
        let filename = path.split(separator: "/").last.map(String.init) ?? path
        return filename.hasSuffix(".md") ? String(filename.dropLast(3)) : filename
    }
}
