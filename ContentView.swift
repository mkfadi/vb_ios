// ContentView.swift – Navigation-Root und App-weiter Zustand

import SwiftUI
import Combine

// Zentraler App-Zustand: wird über .environmentObject() an alle Views weitergereicht
@MainActor
class AppViewModel: ObservableObject {

    @Published var isSetupComplete: Bool = false
    @Published var notes: [String: Note] = [:]   // path → Note (Cache)
    @Published var graphModel = GraphModel()

    private var githubService: GitHubService?
    private var graphModelSink: AnyCancellable?

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

    // Schickt eine geänderte Notiz zu GitHub und aktualisiert den lokalen Cache
    func updateNote(_ note: Note) async throws {
        guard let svc = githubService else { throw GitHubError.unauthorized }
        let newSHA = try await svc.updateNote(note)
        var updated = note
        updated.sha  = newSHA
        notes[note.id] = updated
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
        graphModel      = GraphModel()
        isSetupComplete = false
        subscribeToGraphModel()
    }
}

// Navigation-Root: zeigt Setup- oder Brain-View je nach Authentifizierungsstatus
// viewModel kommt via .environmentObject() aus vb_iosApp – nicht selbst erstellen
struct ContentView: View {
    @EnvironmentObject private var viewModel: AppViewModel

    var body: some View {
        Group {
            if viewModel.isSetupComplete {
                BrainView()
            } else {
                SetupView()
            }
        }
    }
}
