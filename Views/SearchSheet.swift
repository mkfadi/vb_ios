// SearchSheet.swift - In-app graph search and filtering

import SwiftUI

struct SearchSheet: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isSearchFocused: Bool

    let onSelect: (String) -> Void

    @State private var query = ""
    @State private var debouncedQuery = ""
    @State private var selectedPathFilter: PathFilter?
    @State private var selectedStatus: String?
    @State private var debounceTask: Task<Void, Never>?

    private var index: [SearchIndexItem] {
        SearchIndexItem.build(from: viewModel.notes.values)
    }

    private var results: [SearchIndexItem] {
        let needle = debouncedQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return index
            .compactMap { item -> (SearchIndexItem, Int)? in
                guard matchesFilters(item) else { return nil }
                let score = score(item, needle: needle)
                guard score > 0 else { return nil }
                return (item, score)
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return lhs.0.displayTitle.localizedCaseInsensitiveCompare(rhs.0.displayTitle) == .orderedAscending
            }
            .prefix(30)
            .map(\.0)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 10)

                filterScroller
                    .padding(.bottom, 8)

                if results.isEmpty {
                    emptyState
                } else {
                    List(results) { item in
                        Button {
                            onSelect(item.id)
                            dismiss()
                        } label: {
                            SearchResultRow(item: item)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.vbDeep.ignoresSafeArea())
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.vbLavender)
                }
            }
            .onAppear {
                debouncedQuery = query
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    isSearchFocused = true
                }
            }
            .onChange(of: query) { _, newValue in
                debounceTask?.cancel()
                debounceTask = Task {
                    try? await Task.sleep(for: .milliseconds(150))
                    guard !Task.isCancelled else { return }
                    await MainActor.run { debouncedQuery = newValue }
                }
            }
            .onDisappear { debounceTask?.cancel() }
        }
        .presentationCornerRadius(28)
        .presentationBackground(Color.vbDeep)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.vbFg3)
            TextField("Find note", text: $query)
                .focused($isSearchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .foregroundColor(.vbFg1)
            if !query.isEmpty {
                Button {
                    query = ""
                    debouncedQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.vbFg4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.88))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.vbPink.opacity(0.14), lineWidth: 1))
    }

    private var filterScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "Alle",
                    isSelected: selectedPathFilter == nil && selectedStatus == nil,
                    tint: .vbPink
                ) {
                    selectedPathFilter = nil
                    selectedStatus = nil
                }

                ForEach(PathFilter.allCases) { filter in
                    FilterChip(title: filter.title, isSelected: selectedPathFilter == filter, tint: .vbPink) {
                        toggle(filter)
                    }
                }

                ForEach(["wip", "done", "evergreen"], id: \.self) { status in
                    FilterChip(title: status, isSelected: selectedStatus == status, tint: statusColor(status)) {
                        toggleStatus(status)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 26, weight: .semibold))
                .foregroundColor(.vbLavender)
            Text("Keine Treffer")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.vbFg2)
            Text("Versuch einen Titel, Dateinamen oder anderen Filter.")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.vbFg3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 34)
    }

    private func toggle(_ filter: PathFilter) {
        if selectedPathFilter == filter {
            selectedPathFilter = nil
        } else {
            selectedPathFilter = filter
            selectedStatus = nil
        }
    }

    private func toggleStatus(_ status: String) {
        if selectedStatus == status {
            selectedStatus = nil
        } else {
            selectedStatus = status
            selectedPathFilter = nil
        }
    }

    private func matchesFilters(_ item: SearchIndexItem) -> Bool {
        if let selectedPathFilter, !item.pathLower.hasPrefix(selectedPathFilter.prefix) {
            return false
        }
        if let selectedStatus {
            guard item.status == selectedStatus else { return false }
        }
        return true
    }

    private func score(_ item: SearchIndexItem, needle: String) -> Int {
        guard !needle.isEmpty else { return 1 }
        var value = 0
        if item.fileNameLower.hasPrefix(needle) { value += 120 }
        if item.titleLower.hasPrefix(needle) { value += 80 }
        if item.fileNameLower.contains(needle) { value += 45 }
        if item.titleLower.contains(needle) { value += 35 }
        if item.pathLower.contains(needle) { value += 15 }
        return value
    }
}

private struct SearchResultRow: View {
    let item: SearchIndexItem

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(item.displayTitle)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.vbFg1)
                        .lineLimit(1)
                    if let type = item.type {
                        Text(type)
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(.vbFg2)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background((nodeTypeColor(type) ?? Color.vbLavender).opacity(0.13))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke((nodeTypeColor(type) ?? Color.vbLavender).opacity(0.30), lineWidth: 1))
                    }
                }
                Text(item.displayPath)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(.vbFg3)
                    .lineLimit(1)
            }
            Spacer()
            Image(systemName: "scope")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.vbPink.opacity(0.75))
        }
        .padding(.vertical, 7)
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(isSelected ? .white : .vbFg2)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(isSelected ? tint : Color.white.opacity(0.78))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(tint.opacity(isSelected ? 0.0 : 0.22), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private enum PathFilter: String, CaseIterable, Identifiable {
    case projects
    case concepts
    case daily
    case inbox

    var id: String { rawValue }

    var title: String {
        switch self {
        case .projects: return "Projects"
        case .concepts: return "Concepts"
        case .daily: return "Daily"
        case .inbox: return "Inbox"
        }
    }

    var prefix: String {
        switch self {
        case .projects: return "projects/"
        case .concepts: return "concepts/"
        case .daily: return "daily/"
        case .inbox: return "inbox/"
        }
    }
}

private struct SearchIndexItem: Identifiable {
    let id: String
    let displayTitle: String
    let displayPath: String
    let fileNameLower: String
    let titleLower: String
    let pathLower: String
    let type: String?
    let status: String?

    static func build(from notes: Dictionary<String, Note>.Values) -> [SearchIndexItem] {
        notes.map { note in
            let title = firstHeading(in: note.content) ?? note.name
            return SearchIndexItem(
                id: note.id,
                displayTitle: title,
                displayPath: note.path.removingMarkdownExtension,
                fileNameLower: note.name.lowercased(),
                titleLower: title.lowercased(),
                pathLower: note.path.lowercased(),
                type: note.frontmatter?.type,
                status: note.frontmatter?.status
            )
        }
    }

    private static func firstHeading(in content: String) -> String? {
        for line in content.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("# ") else { continue }
            let title = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            return title.isEmpty ? nil : title
        }
        return nil
    }
}

private extension String {
    var removingMarkdownExtension: String {
        hasSuffix(".md") ? String(dropLast(3)) : self
    }
}
