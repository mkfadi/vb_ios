// TodayView.swift – Daily status landing tab

import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @AppStorage("lastSeenDate") private var lastSeenDate = ""

    @State private var statusNote: Note?
    @State private var dailyNote: Note?
    @State private var noteToOpen: TodayNoteRoute?
    @State private var isRefreshing = false
    @State private var isCreatingDaily = false
    @State private var errorMessage: String?

    private var todayPath: String { "daily/\(Self.isoDayFormatter.string(from: Date())).md" }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [.vbVoid, .vbDeep, Color.white],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        header

                        if let errorMessage {
                            errorCard(errorMessage)
                        }

                        activeFocusCard
                        prioritiesCard
                        dailyCard
                        inboxCard
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 28)
                }
                .refreshable { await refresh(forceNetwork: true) }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .task { await initialLoad() }
            .sheet(item: $noteToOpen) { route in
                NoteView(noteID: route.path).environmentObject(viewModel)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Self.weekdayFormatter.string(from: Date()))
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.vbPink)
            Text(Self.fullDateFormatter.string(from: Date()))
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.vbFg1)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.top, 4)
    }

    private var activeFocusCard: some View {
        todayCard(title: "Aktiver Fokus", icon: "target") {
            Button { noteToOpen = TodayNoteRoute(path: "STATUS.md") } label: {
                VStack(alignment: .leading, spacing: 10) {
                    if let focus = statusSection("Aktiver Fokus") {
                        MarkdownView(content: focus)
                    } else {
                        placeholder("Kein aktiver Fokus in STATUS.md gefunden.")
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "hand.tap")
                        Text("Tap zum Öffnen")
                    }
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.vbPink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
    }

    private var prioritiesCard: some View {
        todayCard(title: "Nächste Prioritäten", icon: "list.number") {
            if let priorities = numberedPriorities, !priorities.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(Array(priorities.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 10) {
                            Text("\(index + 1).")
                                .font(.system(size: 14, weight: .heavy, design: .rounded))
                                .foregroundColor(.vbPink)
                                .frame(width: 24, alignment: .trailing)
                            MarkdownView(content: item)
                        }
                    }
                }
            } else {
                placeholder("Keine Prioritäten in STATUS.md gefunden.")
            }
        }
    }

    private var dailyCard: some View {
        todayCard(title: "Heute", icon: "calendar") {
            if let dailyNote {
                Button { noteToOpen = TodayNoteRoute(path: dailyNote.path) } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(todayPath)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(.vbFg3)
                        MarkdownView(content: dailyPreview(dailyNote.content))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 11) {
                    placeholder("Für heute gibt es noch keine Daily-Note.")
                    Button { Task { await createDailyNote() } } label: {
                        HStack(spacing: 8) {
                            if isCreatingDaily { ProgressView().tint(.vbPink).scaleEffect(0.78) }
                            Image(systemName: "plus")
                            Text("Daily-Note anlegen")
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.vbPink)
                        .clipShape(Capsule())
                    }
                    .disabled(isCreatingDaily)
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var inboxCard: some View {
        todayCard(title: "Inbox", icon: "tray.full", badge: inboxNotes.count) {
            if inboxNotes.isEmpty {
                placeholder("Inbox ist leer.")
            } else {
                VStack(spacing: 8) {
                    ForEach(inboxNotes) { note in
                        Button { noteToOpen = TodayNoteRoute(path: note.path) } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.vbPink)
                                    .frame(width: 28, height: 28)
                                    .background(Color.vbPink.opacity(0.10))
                                    .clipShape(Circle())
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(note.name)
                                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                                        .foregroundColor(.vbFg1)
                                        .lineLimit(1)
                                    Text(note.path)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.vbFg3)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.vbFg4)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func todayCard<Content: View>(title: String, icon: String, badge: Int? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 9) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.vbPink)
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.54))
                    .clipShape(Circle())
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.vbFg1)
                if let badge {
                    Text("\(badge)")
                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                        .foregroundColor(.vbPink)
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.vbPink.opacity(0.12))
                        .clipShape(Capsule())
                }
                Spacer()
            }

            content()
        }
        .padding(15)
        .background { LiquidGlassPanel(cornerRadius: 24, tint: .vbPink, opacity: 0.58) }
    }

    private func placeholder(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .foregroundColor(.vbFg3)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func errorCard(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(text)
        }
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .foregroundColor(.vbDanger)
        .padding(12)
        .background(Color.white.opacity(0.68))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func statusSection(_ title: String) -> String? {
        guard let statusNote else { return nil }
        let clean = MarkdownSectionParser.removingFrontmatter(from: statusNote.content)
        return MarkdownSectionParser.section(named: title, in: clean)
    }

    private var numberedPriorities: [String]? {
        guard let section = statusSection("Nächste Prioritäten") else { return nil }
        let items = section.components(separatedBy: .newlines).compactMap { line -> String? in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            if let match = trimmed.firstMatch(of: /^\d+\.\s+(.*)$/) { return String(match.output.1) }
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") { return String(trimmed.dropFirst(2)) }
            return trimmed
        }
        return items
    }

    private var inboxNotes: [Note] {
        viewModel.notes.values
            .filter { note in
                let path = note.path.lowercased()
                return path.hasPrefix("inbox/") && path != "inbox/readme.md"
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func dailyPreview(_ content: String) -> String {
        MarkdownSectionParser.removingFrontmatter(from: content)
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .prefix(5)
            .joined(separator: "\n")
    }

    private func initialLoad() async {
        let today = Self.isoDayFormatter.string(from: Date())
        let newDay = lastSeenDate != today
        if newDay { lastSeenDate = today }
        await refresh(forceNetwork: newDay)
    }

    private func refresh(forceNetwork: Bool) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        errorMessage = nil

        if viewModel.notes.isEmpty {
            await viewModel.loadNotes()
        }

        do {
            if forceNetwork {
                statusNote = try await viewModel.fetchNote(path: "STATUS.md")
            } else if let cached = viewModel.notes["STATUS.md"] {
                statusNote = cached
            } else {
                statusNote = try await viewModel.fetchNote(path: "STATUS.md")
            }
        } catch {
            errorMessage = "STATUS.md konnte nicht geladen werden: \(error.localizedDescription)"
        }

        do {
            if forceNetwork {
                dailyNote = try await viewModel.fetchNote(path: todayPath)
            } else if let cached = viewModel.notes[todayPath] {
                dailyNote = cached
            } else {
                dailyNote = try await viewModel.fetchNote(path: todayPath)
            }
        } catch GitHubError.notFound {
            dailyNote = nil
        } catch {
            dailyNote = nil
        }

        isRefreshing = false
    }

    private func createDailyNote() async {
        isCreatingDaily = true
        do {
            let path = try await viewModel.createOrOpenTodayNote()
            dailyNote = viewModel.notes[path]
            noteToOpen = TodayNoteRoute(path: path)
        } catch {
            errorMessage = error.localizedDescription
        }
        isCreatingDaily = false
    }

    private static let isoDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let fullDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "d. MMMM yyyy"
        return formatter
    }()

    private static let weekdayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.dateFormat = "EEEE"
        return formatter
    }()
}

private struct TodayNoteRoute: Identifiable {
    let path: String
    var id: String { path }
}
