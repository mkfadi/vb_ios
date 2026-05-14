//
//  NoteView.swift
//  vb_ios

import SwiftUI

struct NoteView: View {
    let noteID: String
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var note: Note?
    @State private var editBuffer  = ""
    @State private var isEditing   = false
    @State private var isSaving    = false
    @State private var isLoading   = true
    @State private var errorMsg: String?
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.vbDeep.ignoresSafeArea()

                if isLoading {
                    VStack(spacing: 16) {
                        PearlView(size: 44)
                        Text("Lade Node …")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.vbFg3)
                    }
                } else if let note {
                    noteBody(note)
                } else {
                    errorBody
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.vbDeep, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar { toolbarContent }
            .overlay(alignment: .top) { successBanner }
        }
        .presentationCornerRadius(28)
        .presentationBackground(Color.vbDeep)
        .task { await loadNote() }
    }

    @ViewBuilder
    private func noteBody(_ note: Note) -> some View {
        if isEditing { editorView } else { readView(note) }
    }

    private func readView(_ note: Note) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Node date stamp
                Text(formattedDate())
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.vbPink)
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .padding(.horizontal, 28)
                    .padding(.top, 16)
                    .padding(.bottom, 4)

                // Note title
                Text(note.name)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.vbFg1)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 22)

                // Markdown body
                MarkdownView(content: note.content)
                    .padding(.horizontal, 28)

                // Backlinks
                if !note.links.isEmpty {
                    Color.vbLavender.opacity(0.20)
                        .frame(height: 1)
                        .padding(.horizontal, 28)
                        .padding(.top, 30)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 6) {
                            Image(systemName: "link")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.vbLavender)
                            Text("Verknüpfte Nodes (\(Set(note.links).count))")
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(1.0)
                                .textCase(.uppercase)
                                .foregroundColor(.vbFg3)
                        }
                        BacklinkPillsView(links: Array(Set(note.links)).sorted())
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 18)
                    .padding(.bottom, 44)
                }
            }
        }
    }

    private var editorView: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 10))
                        .foregroundColor(.vbLavender)
                    Text("Node bearbeiten")
                        .font(.system(size: 11, weight: .semibold))
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundColor(.vbLavender)
                }
                Spacer()
                Button("Abbrechen") {
                    isEditing = false
                    errorMsg  = nil
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.vbDanger)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.vbNebula)

            if let err = errorMsg {
                Text(err)
                    .font(.system(size: 12))
                    .foregroundColor(.vbDanger)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            }

            TextEditor(text: $editBuffer)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .foregroundColor(.vbFg1)
                .font(.system(size: 14, design: .monospaced))
                .padding(.horizontal, 12)
        }
    }

    private var errorBody: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 36))
                .foregroundColor(.vbDanger)
            Text(errorMsg ?? "Unbekannter Fehler")
                .foregroundColor(.vbFg2)
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
            Button("Erneut versuchen") { Task { await loadNote() } }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.vbLavender)
        }
        .padding()
    }

    @ViewBuilder
    private var successBanner: some View {
        if showSuccess {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.vbSuccess)
                Text("Auf GitHub gespeichert")
                    .foregroundColor(.vbFg1)
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(Color.white.opacity(0.94))
            .shadow(color: Color.vbPink.opacity(0.14), radius: 18, y: 8)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.vbSuccess.opacity(0.5), lineWidth: 1))
            .padding(.top, 8)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Schließen") { dismiss() }
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.vbLavender)
        }
        if note != nil {
            ToolbarItem(placement: .topBarTrailing) {
                if isEditing {
                    Button { Task { await saveNote() } } label: {
                        if isSaving {
                            ProgressView().tint(.vbLavender).scaleEffect(0.8)
                        } else {
                            Text("Speichern")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.vbSuccess)
                        }
                    }
                    .disabled(isSaving)
                } else {
                    Button("Bearbeiten") {
                        editBuffer = note?.content ?? ""
                        isEditing  = true
                    }
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.vbLavender)
                }
            }
        }
    }

    private func formattedDate() -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "de_DE")
        df.dateFormat = "d. MMMM — EEEE"
        return df.string(from: Date())
    }

    private func loadNote() async {
        isLoading = true
        errorMsg  = nil
        if let cached = viewModel.notes[noteID] {
            note       = cached
            editBuffer = cached.content
            isLoading  = false
            return
        }
        do {
            let fetched = try await viewModel.fetchNote(path: noteID)
            note        = fetched
            editBuffer  = fetched.content
        } catch {
            errorMsg = error.localizedDescription
        }
        isLoading = false
    }

    private func saveNote() async {
        guard var updated = note else { return }
        isSaving = true
        errorMsg = nil
        updated.content = editBuffer
        updated.links   = parseWikilinks(in: editBuffer)
        updated.frontmatter = FrontmatterParser.parse(editBuffer)
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

    private func parseWikilinks(in content: String) -> [String] {
        guard let re = try? NSRegularExpression(pattern: #"\[\[([^\[\]\n]+?)\]\]"#) else { return [] }
        let range = NSRange(content.startIndex..., in: content)
        return re.matches(in: content, range: range).compactMap { m in
            guard let r = Range(m.range(at: 1), in: content) else { return nil }
            return String(content[r]).split(separator: "|").first.map(String.init)
        }
    }
}

// MARK: – Backlink Pills (wrapping layout)

private struct BacklinkPillsView: View {
    let links: [String]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(links, id: \.self) { link in
                Text("[[\(link)]]")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.vbLavender)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.vbLavender.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.vbLavender.opacity(0.32), lineWidth: 1))
            }
        }
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 { x = 0; y += rowH + spacing; rowH = 0 }
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
        return CGSize(width: width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX { x = bounds.minX; y += rowH + spacing; rowH = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowH = max(rowH, size.height)
        }
    }
}

// MARK: – Markdown Renderer

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
        if line.hasPrefix("# ") {
            Text(line.dropFirst(2))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.vbFg1)
                .padding(.top, 12)
        } else if line.hasPrefix("## ") {
            Text(line.dropFirst(3))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundColor(.vbFg1)
                .padding(.top, 8)
        } else if line.hasPrefix("### ") {
            Text(line.dropFirst(4))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.vbFg1.opacity(0.9))
                .padding(.top, 5)
        } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
            HStack(alignment: .top, spacing: 8) {
                Text("·")
                    .foregroundColor(.vbLavender)
                    .font(.system(size: 16, weight: .bold))
                inlineText(String(line.dropFirst(2)))
                    .foregroundColor(.vbFg2)
            }
        } else if let match = line.firstMatch(of: /^(\d+)\. (.*)/) {
            HStack(alignment: .top, spacing: 8) {
                Text("\(match.output.1).")
                    .foregroundColor(.vbLavender)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(minWidth: 20, alignment: .trailing)
                inlineText(String(match.output.2)).foregroundColor(.vbFg2)
            }
        } else if line.hasPrefix("> ") {
            HStack(spacing: 10) {
                LinearGradient(colors: [.vbPink, .vbLavender], startPoint: .top, endPoint: .bottom)
                    .frame(width: 2)
                    .cornerRadius(1)
                inlineText(String(line.dropFirst(2)))
                    .foregroundColor(.vbFg3)
                    .italic()
            }
            .padding(.vertical, 2)
        } else if line.hasPrefix("```") {
            Text(line.isEmpty ? " " : line)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.vbSuccess.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.04))
                .cornerRadius(6)
        } else if line == "---" || line == "***" {
            Color.vbLavender.opacity(0.20)
                .frame(height: 1)
                .cornerRadius(1)
                .padding(.vertical, 8)
        } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
            Spacer().frame(height: 6)
        } else {
            inlineText(line)
                .foregroundColor(.vbFg2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func inlineText(_ text: String) -> Text {
        var attrStr: AttributedString
        do {
            attrStr = try AttributedString(
                markdown: text,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )
        } catch {
            attrStr = AttributedString(text)
        }
        if let re = try? NSRegularExpression(pattern: #"\[\[[^\[\]]+\]\]"#) {
            let range = NSRange(text.startIndex..., in: text)
            for m in re.matches(in: text, range: range).reversed() {
                if let strRange  = Range(m.range, in: text),
                   let attrRange = Range(strRange, in: attrStr) {
                    attrStr[attrRange].foregroundColor = Color.vbLavender
                    attrStr[attrRange].font = Font.system(size: 15, weight: .semibold)
                }
            }
        }
        return Text(attrStr)
    }
}
