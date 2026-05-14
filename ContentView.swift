// ContentView.swift – Navigation-Root und App-weiter Zustand

import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif

// Zentraler App-Zustand: wird ueber .environmentObject() an alle Views weitergereicht
@MainActor
class AppViewModel: ObservableObject {

    @Published var isSetupComplete: Bool = false
    @Published var notes: [String: Note] = [:]   // path → Note (Cache)
    @Published var graphModel = GraphModel()
    @Published var changeHistory: [ChangeHistoryEntry] = []
    @Published var isHistoryLoading = false
    @Published var historyErrorMessage: String?

    private var githubService: GitHubService?
    private var graphModelSink: AnyCancellable?

    var topLevelFolders: [String] {
        let folders = Set(notes.keys.compactMap { path -> String? in
            guard let first = path.split(separator: "/").first,
                  path.contains("/") else { return nil }
            return String(first)
        })
        return Array(folders).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    init() {
        // Beim Start gespeicherte Credentials laden und Service initialisieren
        if let token = KeychainService.loadToken(),
           let repo  = KeychainService.loadRepo(),
           let svc   = try? GitHubService(token: token, repoPath: repo) {
            githubService    = svc
            isSetupComplete  = true
        }
        subscribeToGraphModel()
    }

    private func subscribeToGraphModel() {
        graphModelSink = graphModel.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
    }

    // Validiert Credentials, speichert sie und richtet den Service ein
    func setup(token: String, repo: String) async throws {
        let svc = try GitHubService(token: token, repoPath: repo)
        _ = try await svc.validateConnection()
        KeychainService.saveToken(token)
        KeychainService.saveRepo(repo)
        githubService   = svc
        isSetupComplete = true
        await loadHistory()
    }

    // Lädt alle Notizen vom GitHub-Repo und baut den Graphen auf
    func loadNotes() async {
        guard let svc = githubService else { return }
        graphModel.isLoading      = true
        graphModel.loadingProgress = 0
        graphModel.errorMessage   = nil

        do {
            let list = try await svc.fetchAllNotes { [weak self] progress in
                // Progress-Update muss auf dem Main-Thread landen
                Task { @MainActor [weak self] in
                    self?.graphModel.loadingProgress = progress
                }
            }
            notes = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
            await graphModel.build(from: list)
        } catch {
            graphModel.errorMessage = error.localizedDescription
        }

        graphModel.isLoading = false
    }

    // Laedt die GitHub-Commit-History fuer den Updates-Tab
    func loadHistory() async {
        guard let svc = githubService else { return }
        isHistoryLoading = true
        historyErrorMessage = nil
        do {
            changeHistory = try await svc.fetchChangeHistory(limit: 50)
        } catch {
            historyErrorMessage = error.localizedDescription
        }
        isHistoryLoading = false
    }

    // Erstellt eine neue Quick-Capture-Notiz und lädt den Graph danach neu.
    func createCapturedNote(title: String, body: String, type: String, sendToInbox: Bool, folder: String?) async throws -> String {
        guard let svc = githubService else { throw GitHubError.unauthorized }
        let targetFolder = sendToInbox ? "inbox" : sanitizedFolder(folder)
        let path = uniquePath(folder: targetFolder, title: title)
        let content = noteContent(title: title, body: body, type: type)
        _ = try await svc.createNote(path: path, content: content, message: captureCommitMessage(title: title, path: path))
        await loadNotes()
        await loadHistory()
        return path
    }

    func createOrOpenTodayNote() async throws -> String {
        guard let svc = githubService else { throw GitHubError.unauthorized }
        let date = Self.isoDayFormatter.string(from: Date())
        let path = "daily/\(date).md"

        if notes[path] != nil { return path }

        do {
            let existing = try await svc.fetchNote(path: path)
            notes[path] = existing
            return path
        } catch GitHubError.notFound {
            let content = Self.dailyTemplate(for: date)
            _ = try await svc.createNote(path: path, content: content, message: captureCommitMessage(title: date, path: path))
            await loadNotes()
            await loadHistory()
            return path
        }
    }

    // Schickt eine geänderte Notiz zu GitHub und aktualisiert den lokalen Cache
    func updateNote(_ note: Note) async throws {
        guard let svc = githubService else { throw GitHubError.unauthorized }
        let newSHA = try await svc.updateNote(note, message: commitMessage(for: note))
        var updated = note
        updated.sha  = newSHA
        notes[note.id] = updated
        await loadHistory()
    }

    func renameNote(path: String, to newTitle: String) async throws -> String {
        guard let svc = githubService else { throw GitHubError.unauthorized }
        let cleanTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { throw GitHubError.encodingError }
        let note = try await noteForMutation(path: path)
        let newPath = uniqueRenamedPath(for: note.path, title: cleanTitle)
        let newContent = contentRenamed(note.content, title: cleanTitle)
        let oldName = note.name
        let newName = Note.extractName(from: newPath)

        _ = try await svc.renameNote(note, to: newPath, newContent: newContent, message: renameCommitMessage(from: note.path, to: newPath, title: cleanTitle))
        try await updateWikilinksForRename(from: oldName, to: newName, excluding: [note.path, newPath], service: svc)
        notes.removeValue(forKey: note.path)
        await loadNotes()
        await loadHistory()
        return newPath
    }

    func deleteNote(path: String) async throws {
        guard let svc = githubService else { throw GitHubError.unauthorized }
        let note = try await noteForMutation(path: path)
        try await svc.deleteNote(path: note.path, sha: note.sha, message: deleteCommitMessage(for: note))
        notes.removeValue(forKey: note.path)
        await loadNotes()
        await loadHistory()
    }

    private func noteForMutation(path: String) async throws -> Note {
        if let note = notes[path] { return note }
        return try await fetchNote(path: path)
    }

    // Holt eine einzelne Notiz frisch von GitHub (wenn nicht im Cache)
    func fetchNote(path: String) async throws -> Note {
        guard let svc = githubService else { throw GitHubError.unauthorized }
        let note = try await svc.fetchNote(path: path)
        notes[path] = note
        return note
    }

    // Meldet den Nutzer ab und löscht alle lokalen Daten
    func logout() {
        KeychainService.clearAll()
        githubService   = nil
        notes           = [:]
        changeHistory   = []
        historyErrorMessage = nil
        graphModel      = GraphModel()
        isSetupComplete = false
        subscribeToGraphModel()
    }

    private func commitMessage(for note: Note) -> String {
        """
        Update \(note.name) via Synaptic Vault

        Device: \(Self.deviceName)
        System: \(Self.systemName)
        Path: \(note.path)
        App: Synaptic Vault
        """
    }

    private func captureCommitMessage(title: String, path: String) -> String {
        """
        capture: \(title.trimmingCharacters(in: .whitespacesAndNewlines))

        Device: \(Self.deviceName)
        System: \(Self.systemName)
        Path: \(path)
        App: Synaptic Vault
        """
    }

    private func renameCommitMessage(from oldPath: String, to newPath: String, title: String) -> String {
        """
        rename: \(title)

        Device: \(Self.deviceName)
        System: \(Self.systemName)
        Path: \(oldPath) -> \(newPath)
        App: Synaptic Vault
        """
    }

    private func deleteCommitMessage(for note: Note) -> String {
        """
        delete: \(note.name)

        Device: \(Self.deviceName)
        System: \(Self.systemName)
        Path: \(note.path)
        App: Synaptic Vault
        """
    }

    private func renameLinksCommitMessage(from oldName: String, to newName: String, path: String) -> String {
        """
        rename links: \(oldName) -> \(newName)

        Device: \(Self.deviceName)
        System: \(Self.systemName)
        Path: \(path)
        App: Synaptic Vault
        """
    }

    private static func dailyTemplate(for date: String) -> String {
        """
        # \(date)

        #daily

        ---

        ##

        """
    }

    private func noteContent(title: String, body: String, type: String) -> String {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let date = Self.isoDayFormatter.string(from: Date())
        let bodyBlock = cleanBody.isEmpty ? "" : "\n\n\(cleanBody)"
        return """
        ---
        updated: \(date)
        status: wip
        type: \(type)
        ---

        # \(cleanTitle)\(bodyBlock)

        """
    }

    private func uniquePath(folder: String, title: String) -> String {
        let slug = Self.slugify(title)
        let baseFolder = sanitizedFolder(folder)
        let existing = Set(notes.keys.map { $0.lowercased() })
        var candidate = "\(baseFolder)/\(slug).md"
        var index = 2
        while existing.contains(candidate.lowercased()) {
            candidate = "\(baseFolder)/\(slug)-\(index).md"
            index += 1
        }
        return candidate
    }

    private func uniqueRenamedPath(for oldPath: String, title: String) -> String {
        let slug = Self.slugify(title)
        let folder = oldPath.split(separator: "/").dropLast().joined(separator: "/")
        let prefix = folder.isEmpty ? "" : "\(folder)/"
        let existing = Set(notes.keys.filter { $0 != oldPath }.map { $0.lowercased() })
        var candidate = "\(prefix)\(slug).md"
        var index = 2
        while existing.contains(candidate.lowercased()) {
            candidate = "\(prefix)\(slug)-\(index).md"
            index += 1
        }
        return candidate
    }

    private func contentRenamed(_ content: String, title: String) -> String {
        var lines = content.components(separatedBy: .newlines)
        if let firstHeading = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("# ") }) {
            lines[firstHeading] = "# \(title)"
            return lines.joined(separator: "\n")
        }
        return "# \(title)\n\n\(content)"
    }

    private func updateWikilinksForRename(from oldName: String, to newName: String, excluding excludedPaths: Set<String>, service: GitHubService) async throws {
        for var linkedNote in notes.values where !excludedPaths.contains(linkedNote.path) {
            let updatedContent = contentUpdatingWikilinks(linkedNote.content, from: oldName, to: newName)
            guard updatedContent != linkedNote.content else { continue }
            linkedNote.content = updatedContent
            _ = try await service.updateNote(linkedNote, message: renameLinksCommitMessage(from: oldName, to: newName, path: linkedNote.path))
        }
    }

    private func contentUpdatingWikilinks(_ content: String, from oldName: String, to newName: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"\[\[([^\[\]\n]+?)\]\]"#) else { return content }
        let range = NSRange(content.startIndex..., in: content)
        var output = content

        for match in regex.matches(in: content, range: range).reversed() {
            guard let fullRange = Range(match.range(at: 0), in: output),
                  let innerRange = Range(match.range(at: 1), in: content) else { continue }
            let inner = String(content[innerRange])
            let parts = inner.split(separator: "|", maxSplits: 1, omittingEmptySubsequences: false)
            guard let target = parts.first, target.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(oldName) == .orderedSame else { continue }
            let alias = parts.count > 1 ? "|\(parts[1])" : ""
            output.replaceSubrange(fullRange, with: "[[\(newName)\(alias)]]")
        }

        return output
    }

    private func sanitizedFolder(_ folder: String?) -> String {
        let cleaned = (folder ?? "inbox")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: "/")
            .first
            .map(String.init) ?? "inbox"
        return cleaned.isEmpty ? "inbox" : cleaned
    }

    private static func slugify(_ title: String) -> String {
        let mapped = title.lowercased()
            .replacingOccurrences(of: "ä", with: "ae")
            .replacingOccurrences(of: "ö", with: "oe")
            .replacingOccurrences(of: "ü", with: "ue")
            .replacingOccurrences(of: "ß", with: "ss")
        let scalars = mapped.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) { return Character(scalar) }
            return "-"
        }
        let collapsed = String(scalars)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return collapsed.isEmpty ? "untitled" : collapsed
    }

    private static let isoDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static var deviceName: String {
        #if os(iOS)
        UIDevice.current.name
        #else
        "Unbekanntes Geraet"
        #endif
    }

    private static var systemName: String {
        #if os(iOS)
        "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        #else
        "Unbekanntes System"
        #endif
    }
}

// Navigation-Root: zeigt Setup- oder App-Tabs je nach Authentifizierungsstatus
// viewModel kommt via .environmentObject() aus vb_iosApp – nicht selbst erstellen
struct ContentView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        Group {
            if viewModel.isSetupComplete {
                MainTabView()
            } else {
                SetupView()
            }
        }
    }
}

private struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tabItem {
                    Label("Heute", systemImage: "sun.max.fill")
                }
                .tag(0)

            BrainView()
                .tabItem {
                    Label("Brain", systemImage: "brain.head.profile")
                }
                .tag(1)

            HistoryView()
                .tabItem {
                    Label("Updates", systemImage: "clock.arrow.circlepath")
                }
                .tag(2)
        }
        .tint(.vbPink)
    }
}

private struct HistoryView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.vbVoid, .vbDeep, Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Group {
                    if viewModel.isHistoryLoading && viewModel.changeHistory.isEmpty {
                        loadingState
                    } else if let message = viewModel.historyErrorMessage {
                        errorState(message)
                    } else if viewModel.changeHistory.isEmpty {
                        emptyState
                    } else {
                        historyList
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            if viewModel.changeHistory.isEmpty {
                await viewModel.loadHistory()
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            PearlView(size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("Updates")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.vbFg1)
                Text("GitHub History · Geräte & Commits")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.vbFg3)
            }

            Spacer()

            Button {
                Task { await viewModel.loadHistory() }
            } label: {
                Image(systemName: viewModel.isHistoryLoading ? "hourglass" : "arrow.clockwise")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.vbPink)
                    .frame(width: 38, height: 38)
                    .background(Color.white.opacity(0.90))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.vbPink.opacity(0.16), lineWidth: 1))
            }
            .disabled(viewModel.isHistoryLoading)
        }
        .padding(.horizontal, 20)
        .padding(.top, 58)
        .padding(.bottom, 18)
        .background(Color.white.opacity(0.72))
    }

    private var historyList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.changeHistory) { entry in
                    HistoryRowView(entry: entry)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 96)
        }
        .refreshable { await viewModel.loadHistory() }
    }

    private var loadingState: some View {
        VStack(spacing: 14) {
            PearlView(size: 56)
            ProgressView()
                .tint(.vbPink)
            Text("Lade GitHub History…")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.vbFg3)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.badge.questionmark")
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(.vbPink)
            Text("Noch keine Updates gefunden")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.vbFg1)
            Text("Sobald GitHub Commits im Vault stehen, erscheinen sie hier.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.vbFg3)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(.vbDanger)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.vbFg2)
                .multilineTextAlignment(.center)
            Button("Erneut laden") {
                Task { await viewModel.loadHistory() }
            }
            .font(.system(size: 14, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(Color.vbPink)
            .clipShape(Capsule())
        }
        .padding(24)
    }
}

private struct HistoryRowView: View {
    let entry: ChangeHistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: entry.device == "Extern / unbekannt" ? "globe" : "iphone.gen3")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.vbPink)
                    .frame(width: 34, height: 34)
                    .background(Color.vbDeep.opacity(0.92))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundColor(.vbFg1)
                        .lineLimit(2)

                    Text(metaLine)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.vbFg3)
                        .monospacedDigit()
                }

                Spacer()
            }

            HStack(spacing: 7) {
                chip(icon: "iphone", text: entry.device)
                if let system = entry.system {
                    chip(icon: "gearshape", text: system)
                }
            }

            if let path = entry.path {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 11, weight: .semibold))
                    Text(path)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundColor(.vbFg3)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.vbPink.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .vbPink.opacity(0.10), radius: 14, y: 6)
    }

    private var metaLine: String {
        let shortSHA = String(entry.sha.prefix(7))
        return "\(formattedDate) · \(entry.author) · \(shortSHA)"
    }

    private var formattedDate: String {
        guard let date = entry.date else { return "GitHub" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "dd.MM. HH:mm"
        return formatter.string(from: date)
    }

    private func chip(icon: String, text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundColor(.vbFg2)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(Color.vbDeep.opacity(0.82))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Color.vbPink.opacity(0.12), lineWidth: 1))
    }
}
