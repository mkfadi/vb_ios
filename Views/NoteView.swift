// NoteView.swift – Notiz anzeigen, bearbeiten und zu GitHub pushen

import SwiftUI

struct NoteView: View {
    let noteID: String
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var note: Note?
    @State private var editBuffer  = ""    // Zwischenspeicher für den Editor
    @State private var isEditing   = false
    @State private var isSaving    = false
    @State private var isLoading   = true
    @State private var errorMsg: String?
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.05, green: 0.02, blue: 0.10).ignoresSafeArea()

                if isLoading {
                    ProgressView("Lade Notiz …").tint(.purple).foregroundColor(.white)
                } else if let note {
                    noteBody(note)
                } else {
                    errorBody
                }
            }
            .navigationTitle(note?.name ?? "Notiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(red: 0.05, green: 0.02, blue: 0.10), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar { toolbarContent }
            .overlay(alignment: .top) { successBanner }
        }
        .task { await loadNote() }
    }

    // Haupt-Body: Editor-Modus oder Lese-Modus
    @ViewBuilder
    private func noteBody(_ note: Note) -> some View {
        if isEditing {
            editorView
        } else {
            readView(note)
        }
    }

    // Lese-Modus: Markdown formatiert anzeigen
    private func readView(_ note: Note) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                MarkdownView(content: note.content)
                    .padding()

                // Verknüpfte Notizen als Chips
                if !note.links.isEmpty {
                    Divider()
                        .background(Color.purple.opacity(0.3))
                        .padding(.horizontal)

                    VStack(alignment: .leading, spacing: 8) {
                        Label("Verknüpfte Notizen (\(note.links.count))", systemImage: "link")
                            .font(.caption.bold())
                            .foregroundColor(.gray)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(note.links, id: \.self) { link in
                                    Text("[[" + link + "]]")
                                        .font(.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.purple.opacity(0.20))
                                        .foregroundColor(.purple)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.purple.opacity(0.4), lineWidth: 1)
                                        )
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    // Editor-Modus: Einfacher Monospace-Editor für Markdown
    private var editorView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Markdown bearbeiten", systemImage: "pencil.and.outline")
                    .font(.caption.bold())
                    .foregroundColor(.purple)
                Spacer()
                Button("Abbrechen") {
                    isEditing  = false
                    errorMsg   = nil
                }
                .font(.caption)
                .foregroundColor(.red)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.3))

            if let err = errorMsg {
                Text(err)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .padding(.top, 6)
            }

            TextEditor(text: $editBuffer)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .foregroundColor(.white)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
        }
    }

    // Fehler-Ansicht wenn Note nicht geladen werden konnte
    private var errorBody: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.red)
            Text(errorMsg ?? "Unbekannter Fehler")
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Button("Erneut versuchen") { Task { await loadNote() } }
                .foregroundColor(.purple)
        }
        .padding()
    }

    // Grüner Erfolgs-Banner der kurz einblendet
    @ViewBuilder
    private var successBanner: some View {
        if showSuccess {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                Text("Auf GitHub gespeichert").foregroundColor(.white).font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(red: 0.05, green: 0.25, blue: 0.10))
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.green.opacity(0.5), lineWidth: 1))
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Schließen") { dismiss() }
                .foregroundColor(.purple)
        }
        if note != nil {
            ToolbarItem(placement: .topBarTrailing) {
                if isEditing {
                    Button {
                        Task { await saveNote() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(.white).scaleEffect(0.8)
                        } else {
                            Text("Speichern").bold().foregroundColor(.green)
                        }
                    }
                    .disabled(isSaving)
                } else {
                    Button("Bearbeiten") {
                        editBuffer = note?.content ?? ""
                        isEditing  = true
                    }
                    .foregroundColor(.purple)
                }
            }
        }
    }

    // Lädt Notiz aus Cache oder frisch von GitHub
    private func loadNote() async {
        isLoading = true
        errorMsg  = nil

        if let cached = viewModel.notes[noteID] {
            note      = cached
            editBuffer = cached.content
            isLoading = false
            return
        }

        do {
            let fetched = try await viewModel.fetchNote(path: noteID)
            note       = fetched
            editBuffer = fetched.content
        } catch {
            errorMsg = error.localizedDescription
        }
        isLoading = false
    }

    // Speichert den aktuellen Editor-Inhalt zu GitHub (erzeugt Commit)
    private func saveNote() async {
        guard var updated = note else { return }
        isSaving = true
        errorMsg = nil

        updated.content = editBuffer
        updated.links   = parseWikilinks(in: editBuffer)

        do {
            try await viewModel.updateNote(updated)
            note      = viewModel.notes[noteID]
            isEditing = false
            withAnimation(.spring()) { showSuccess = true }
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { showSuccess = false }
        } catch {
            errorMsg = error.localizedDescription
        }
        isSaving = false
    }

    // Parst [[wikilinks]] lokal (wird nach dem Speichern für den Note-Cache benötigt)
    private func parseWikilinks(in content: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: #"\[\[([^\[\]\n]+?)\]\]"#) else { return [] }
        let range = NSRange(content.startIndex..., in: content)
        return re.matches(in: content, range: range).compactMap { m in
            guard let r = Range(m.range(at: 1), in: content) else { return nil }
            return String(content[r]).split(separator: "|").first.map(String.init)
        }
    }
}

// MARK: – Markdown-Renderer

// Wandelt gängige Obsidian/Markdown-Syntax in SwiftUI-Views um (kein externes Framework nötig)
struct MarkdownView: View {
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(Array(content.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                renderLine(line)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func renderLine(_ line: String) -> some View {
        // Überschriften H1–H3
        if line.hasPrefix("# ") {
            Text(line.dropFirst(2))
                .font(.title.bold())
                .foregroundColor(.white)
                .padding(.top, 10)

        } else if line.hasPrefix("## ") {
            Text(line.dropFirst(3))
                .font(.title2.bold())
                .foregroundColor(.white)
                .padding(.top, 6)

        } else if line.hasPrefix("### ") {
            Text(line.dropFirst(4))
                .font(.system(.title3, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
                .padding(.top, 4)

        // Aufzählungen (- oder *)
        } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .foregroundColor(.purple)
                    .font(.body.bold())
                inlineText(String(line.dropFirst(2)))
                    .foregroundColor(.white.opacity(0.85))
            }

        // Nummerierte Listen: "1. ", "2. " etc.
        } else if let match = line.firstMatch(of: /^(\d+)\. (.*)/) {
            HStack(alignment: .top, spacing: 8) {
                Text("\(match.output.1).")
                    .foregroundColor(.purple)
                    .font(.body.bold())
                    .frame(minWidth: 20, alignment: .trailing)
                inlineText(String(match.output.2))
                    .foregroundColor(.white.opacity(0.85))
            }

        // Blockzitat
        } else if line.hasPrefix("> ") {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(LinearGradient(colors: [.purple, .blue], startPoint: .top, endPoint: .bottom))
                    .frame(width: 3)
                inlineText(String(line.dropFirst(2)))
                    .foregroundColor(.gray)
                    .italic()
            }
            .padding(.vertical, 2)

        // Code-Block-Marker (```); einfache Darstellung
        } else if line.hasPrefix("```") {
            Text(line.isEmpty ? " " : line)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.green.opacity(0.7))
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.04))
                .cornerRadius(4)

        // Horizontale Linie ---
        } else if line == "---" || line == "***" {
            Rectangle()
                .fill(Color.purple.opacity(0.3))
                .frame(height: 1)
                .padding(.vertical, 6)

        // Leerzeile → kleiner Abstand
        } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
            Spacer().frame(height: 6)

        // Normaler Absatz
        } else {
            inlineText(line)
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // Verarbeitet Inline-Markdown: **fett**, *kursiv*, `code`, [[wikilinks]]
    private func inlineText(_ text: String) -> Text {
        // Nutze AttributedString für Markdown-Inline-Syntax (iOS 15+)
        var attrStr: AttributedString
        do {
            attrStr = try AttributedString(
                markdown: text,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )
        } catch {
            attrStr = AttributedString(text)
        }

        // [[Wikilinks]] nachträglich lila einfärben (wird von AttributedString(markdown:) ignoriert)
        if let re = try? NSRegularExpression(pattern: #"\[\[[^\[\]]+\]\]"#) {
            let ns    = text as NSString
            let range = NSRange(location: 0, length: ns.length)
            for m in re.matches(in: text, range: range).reversed() {
                if let strRange  = Range(m.range, in: text),
                   let attrRange = Range(strRange, in: attrStr) {
                    attrStr[attrRange].foregroundColor = .purple
                    attrStr[attrRange].font = .body.bold()
                }
            }
        }

        return Text(attrStr)
    }
}

