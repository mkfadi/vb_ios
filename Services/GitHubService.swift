// GitHubService.swift – Alle GitHub REST API Aufrufe (als Swift Actor isoliert)

import Foundation

// Eigene Fehlertypen für bessere Fehlermeldungen in der UI
enum GitHubError: LocalizedError {
    case invalidRepoFormat
    case unauthorized
    case notFound
    case rateLimited
    case serverError(Int)
    case decodingError(String)
    case encodingError

    var errorDescription: String? {
        switch self {
        case .invalidRepoFormat: return "Format muss 'owner/repo' sein"
        case .unauthorized:      return "Token ungültig oder abgelaufen"
        case .notFound:          return "Repository nicht gefunden (privat oder falsch geschrieben?)"
        case .rateLimited:       return "GitHub Rate Limit erreicht – bitte kurz warten"
        case .serverError(let c):return "GitHub Server-Fehler: HTTP \(c)"
        case .decodingError(let m): return "Antwort konnte nicht gelesen werden: \(m)"
        case .encodingError:     return "Inhalt konnte nicht kodiert werden"
        }
    }
}

// MARK: – Interne API-Antwort-Strukturen

private struct TreeResponse: Decodable {
    struct Item: Decodable {
        let path: String?
        let type: String?
        let sha:  String?
    }
    let tree: [Item]
}

private struct ContentsResponse: Decodable {
    let name:     String
    let path:     String
    let sha:      String
    let content:  String? // base64-kodiert mit Zeilenumbrüchen
    let encoding: String?
}

private struct UpdateRequest: Encodable {
    let message: String
    let content: String  // base64-kodiert (ohne Zeilenumbrüche)
    let sha:     String  // aktueller SHA der Datei – für optimistisches Locking
}

private struct CreateRequest: Encodable {
    let message: String
    let content: String
}

private struct DeleteRequest: Encodable {
    let message: String
    let sha: String
}

private struct DeleteResponse: Decodable {}

private struct UpdateResponse: Decodable {
    struct FileInfo: Decodable { let sha: String }
    let content: FileInfo
}

private struct RepoInfo: Decodable {
    let full_name: String
    let default_branch: String
}

struct ChangeHistoryEntry: Identifiable, Sendable {
    let id: String
    let sha: String
    let title: String
    let author: String
    let date: Date?
    let device: String
    let system: String?
    let path: String?
    let app: String?
    let url: URL?
}

private struct CommitListItem: Decodable {
    struct CommitInfo: Decodable {
        struct CommitAuthor: Decodable {
            let name: String?
            let date: String?
        }
        let message: String
        let author: CommitAuthor?
    }

    struct GitHubUser: Decodable {
        let login: String?
    }

    let sha: String
    let html_url: String?
    let commit: CommitInfo
    let author: GitHubUser?
}

// MARK: – Haupt-Service als Actor (thread-safe automatisch)

actor GitHubService {

    private let token: String
    private let owner: String
    private let repo:  String
    private let base = "https://api.github.com"

    // Initialisierung: parst "owner/repo" oder volle GitHub-URL in separate Teile
    init(token: String, repoPath: String) throws {
        var normalized = repoPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: normalized),
           let host = url.host, host.contains("github.com") {
            normalized = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            // .git-Suffix entfernen falls vorhanden
            if normalized.hasSuffix(".git") {
                normalized = String(normalized.dropLast(4))
            }
        }
        let parts = normalized.split(separator: "/", maxSplits: 1)
        guard parts.count == 2, !parts[0].isEmpty, !parts[1].isEmpty else {
            throw GitHubError.invalidRepoFormat
        }
        self.token = token
        self.owner = String(parts[0])
        self.repo  = String(parts[1])
    }

    // Erstellt einen authentifizierten URLRequest für die GitHub API v3
    private func request(_ path: String, method: String = "GET") throws -> URLRequest {
        guard let url = URL(string: "\(base)\(path)") else { throw GitHubError.invalidRepoFormat }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(token)",               forHTTPHeaderField: "Authorization")
        req.setValue("application/vnd.github+json",   forHTTPHeaderField: "Accept")
        req.setValue("2022-11-28",                     forHTTPHeaderField: "X-GitHub-Api-Version")
        return req
    }

    // Führt einen Request aus, prüft HTTP-Status und dekodiert die Antwort
    private func perform<T: Decodable>(_ req: URLRequest) async throws -> T {
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: req)
        } catch {
            throw GitHubError.decodingError(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw GitHubError.decodingError("Keine HTTP-Antwort")
        }
        switch http.statusCode {
        case 200...299: break
        case 401:       throw GitHubError.unauthorized
        case 403:       throw GitHubError.rateLimited
        case 404:       throw GitHubError.notFound
        default:        throw GitHubError.serverError(http.statusCode)
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw GitHubError.decodingError(error.localizedDescription)
        }
    }

    // Prüft ob Token und Repo erreichbar sind – gibt Repo-Infos zurück
    func validateConnection() async throws -> String {
        let req = try request("/repos/\(owner)/\(repo)")
        let info: RepoInfo = try await perform(req)
        return info.full_name
    }

    // Lädt den vollständigen Dateibaum des Repos (rekursiv, nur Dateien)
    private func fetchTree() async throws -> [TreeResponse.Item] {
        let req = try request("/repos/\(owner)/\(repo)/git/trees/HEAD?recursive=1")
        let resp: TreeResponse = try await perform(req)
        return resp.tree.filter { $0.type == "blob" }
    }

    // Lädt alle .md Dateien aus dem Repo; ruft `progress` mit 0.0…1.0 auf
    func fetchAllNotes(progress: @escaping @Sendable (Double) -> Void) async throws -> [Note] {
        let tree   = try await fetchTree()
        let mdItems = tree.filter { ($0.path ?? "").hasSuffix(".md") }
        guard !mdItems.isEmpty else { return [] }

        var notes: [Note] = []
        notes.reserveCapacity(mdItems.count)
        let total = Double(mdItems.count)
        var done  = 0.0

        // Lade in Batches von 6 gleichzeitig (schont GitHub Rate Limit)
        let batchSize = 6
        let chunks = stride(from: 0, to: mdItems.count, by: batchSize).map {
            Array(mdItems[$0..<min($0 + batchSize, mdItems.count)])
        }

        for chunk in chunks {
            try await withThrowingTaskGroup(of: Note?.self) { group in
                for item in chunk {
                    guard let path = item.path else { continue }
                    group.addTask { try await self.fetchNote(path: path) }
                }
                for try await note in group {
                    if let note { notes.append(note) }
                    done += 1
                    progress(done / total)
                }
            }
        }
        return notes
    }

    // Lädt eine einzelne Notiz anhand ihres Pfades (inkl. aktueller SHA für spätere Updates)
    func fetchNote(path: String) async throws -> Note {
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        let req     = try request("/repos/\(owner)/\(repo)/contents/\(encoded)")
        let resp: ContentsResponse = try await perform(req)

        let content = decodeBase64(resp.content ?? "")
        let name    = Note.extractName(from: path)
        let links   = parseWikilinks(in: content)
        let frontmatter = FrontmatterParser.parse(content)

        return Note(path: path, name: name, content: content, sha: resp.sha, links: links, frontmatter: frontmatter)
    }

    // Laedt die GitHub-Commit-History fuer den Updates-Tab.
    func fetchChangeHistory(limit: Int = 40) async throws -> [ChangeHistoryEntry] {
        let cappedLimit = max(1, min(limit, 100))
        let req = try request("/repos/\(owner)/\(repo)/commits?per_page=\(cappedLimit)")
        let commits: [CommitListItem] = try await perform(req)
        let formatter = ISO8601DateFormatter()

        return commits.map { item in
            let metadata = Self.metadata(from: item.commit.message)
            let title = Self.title(from: item.commit.message)
            let author = item.author?.login ?? item.commit.author?.name ?? "GitHub"
            let date = item.commit.author?.date.flatMap { formatter.date(from: $0) }
            let device = metadata["Device"] ?? "Extern / unbekannt"

            return ChangeHistoryEntry(
                id: item.sha,
                sha: item.sha,
                title: title,
                author: author,
                date: date,
                device: device,
                system: metadata["System"],
                path: metadata["Path"],
                app: metadata["App"],
                url: item.html_url.flatMap(URL.init(string:))
            )
        }
    }

    // Erstellt eine neue Markdown-Notiz als GitHub Commit (PUT /contents ohne SHA)
    func createNote(path: String, content: String, message: String) async throws -> String {
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        var req     = try request("/repos/\(owner)/\(repo)/contents/\(encoded)", method: "PUT")

        guard let contentData = content.data(using: .utf8) else { throw GitHubError.encodingError }
        let body = CreateRequest(
            message: message,
            content: contentData.base64EncodedString()
        )
        req.httpBody = try JSONEncoder().encode(body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let resp: UpdateResponse = try await perform(req)
        return resp.content.sha
    }

    // Speichert eine geänderte Notiz als neuen Commit auf GitHub (PUT /contents)
    func updateNote(_ note: Note, message: String = "Update via Synaptic Vault") async throws -> String {
        let encoded = note.path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? note.path
        var req     = try request("/repos/\(owner)/\(repo)/contents/\(encoded)", method: "PUT")

        guard let contentData = note.content.data(using: .utf8) else { throw GitHubError.encodingError }
        let body = UpdateRequest(
            message: message,
            content: contentData.base64EncodedString(), // GitHub will base64 ohne Zeilenumbrüche
            sha:     note.sha
        )
        req.httpBody = try JSONEncoder().encode(body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let resp: UpdateResponse = try await perform(req)
        return resp.content.sha // Neuer SHA nach dem Commit
    }

    // Loescht eine Markdown-Notiz als GitHub Commit (DELETE /contents mit SHA)
    func deleteNote(path: String, sha: String, message: String) async throws {
        let encoded = path.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? path
        var req = try request("/repos/\(owner)/\(repo)/contents/\(encoded)", method: "DELETE")
        let body = DeleteRequest(message: message, sha: sha)
        req.httpBody = try JSONEncoder().encode(body)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let _: DeleteResponse = try await perform(req)
    }

    // GitHub hat keinen direkten Rename-Endpunkt: neue Datei anlegen, alte Datei entfernen.
    func renameNote(_ note: Note, to newPath: String, newContent: String, message: String) async throws -> String {
        let newSHA = try await createNote(path: newPath, content: newContent, message: message)
        try await deleteNote(path: note.path, sha: note.sha, message: message)
        return newSHA
    }

    private static func title(from message: String) -> String {
        message
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "GitHub Änderung"
    }

    private static func metadata(from message: String) -> [String: String] {
        var values: [String: String] = [:]
        for line in message.components(separatedBy: .newlines) {
            let parts = line.split(separator: ":", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if ["Device", "System", "Path", "App"].contains(key), !value.isEmpty {
                values[key] = value
            }
        }
        return values
    }

    // Parst alle [[wikilinks]] und [[note|alias]]-Links aus Markdown-Text
    private func parseWikilinks(in content: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"\[\[([^\[\]\n]+?)\]\]"#) else { return [] }
        let range   = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, range: range)
        return matches.compactMap { match -> String? in
            guard let r = Range(match.range(at: 1), in: content) else { return nil }
            // Alias-Syntax: [[Ziel|Anzeigename]] → nur "Ziel" nehmen
            return String(content[r]).split(separator: "|").first.map(String.init)
        }
    }

    // Dekodiert base64-kodierten GitHub-Inhalt (GitHub fügt \n alle 60 Zeichen ein)
    private func decodeBase64(_ encoded: String) -> String {
        let clean = encoded.replacingOccurrences(of: "\n", with: "")
        guard let data = Data(base64Encoded: clean),
              let text = String(data: data, encoding: .utf8) else { return "" }
        return text
    }
}
