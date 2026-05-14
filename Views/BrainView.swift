//
//  BrainView.swift
//  vb_ios

import SwiftUI
import SceneKit   // SCNVector3.x / .y

// MARK: – Design Tokens (module-wide)

extension Color {
    static let vbVoid       = Color(red: 0.998, green: 0.995, blue: 0.992)  // warm white
    static let vbDeep       = Color(red: 0.992, green: 0.965, blue: 0.976)  // blush surface
    static let vbNebula     = Color(red: 1.000, green: 0.930, blue: 0.958)  // soft rose panel
    static let vbRose       = Color(red: 1.000, green: 0.454, blue: 0.682)  // logo rose
    static let vbPink       = Color(red: 0.984, green: 0.137, blue: 0.554)  // logo pink
    static let vbMagenta    = Color(red: 0.918, green: 0.063, blue: 0.457)  // active pink
    static let vbLavender   = Color(red: 0.973, green: 0.337, blue: 0.631)  // brand accent
    static let vbLilac      = Color(red: 1.000, green: 0.690, blue: 0.812)  // pale pink
    static let vbOrchid     = Color(red: 0.940, green: 0.188, blue: 0.527)  // rich node
    static let vbPeriwinkle = Color(red: 1.000, green: 0.800, blue: 0.878)  // light node
    static let vbStardust   = Color.white
    static let warmPeach    = Color(red: 1.000, green: 0.706, blue: 0.557)
    static let softGray     = Color(red: 0.790, green: 0.777, blue: 0.812)
    static let goldAccent   = Color(red: 1.000, green: 0.741, blue: 0.235)
    static let blush        = Color(red: 1.000, green: 0.553, blue: 0.702)
    static let vbFg1        = Color(red: 0.120, green: 0.102, blue: 0.118)  // ink
    static let vbFg2        = Color(red: 0.286, green: 0.243, blue: 0.282)  // graphite
    static let vbFg3        = Color(red: 0.553, green: 0.459, blue: 0.529)  // muted mauve
    static let vbFg4        = Color(red: 0.710, green: 0.610, blue: 0.682)  // soft label
    static let vbSuccess    = Color(red: 0.113, green: 0.640, blue: 0.438)
    static let vbDanger     = Color(red: 0.906, green: 0.153, blue: 0.314)
}

private let hubIncomingThreshold = 5

// MARK: – Brand mark, shared across screens

struct PearlView: View {
    let size: CGFloat

    var body: some View {
        Image("BrainLogo")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.18, style: .continuous))
            .shadow(color: .vbPink.opacity(0.20), radius: size * 0.14, y: size * 0.05)
            .accessibilityLabel("Synaptic Vault Logo")
    }
}

// MARK: – Cosmic Background

private struct CosmicBackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.vbVoid, .vbDeep, Color.white],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [Color.vbPink.opacity(0.13), .clear],
                center: UnitPoint(x: 0.18, y: 0.12),
                startRadius: 0, endRadius: 360
            )
            RadialGradient(
                colors: [Color.vbRose.opacity(0.10), .clear],
                center: UnitPoint(x: 0.86, y: 0.78),
                startRadius: 0, endRadius: 320
            )
            StarfieldView()
        }
        .ignoresSafeArea()
    }
}

private struct StarfieldView: View {
    private static let stars: [(CGFloat, CGFloat, CGFloat, Double)] =
        (0..<60).map { i in
            let x = CGFloat((i * 73) % 390) / 390.0
            let y = CGFloat((i * 137) % 844) / 844.0
            let r = CGFloat(0.4 + Double((i * 13) % 10) / 18.0)
            let alpha = 0.10 + Double((i * 17) % 10) / 70.0
            return (x, y, r, alpha)
        }

    var body: some View {
        Canvas { ctx, size in
            for (nx, ny, r, alpha) in Self.stars {
                ctx.fill(
                    Path(ellipseIn: CGRect(
                        x: nx * size.width  - r,
                        y: ny * size.height - r,
                        width: r * 2, height: r * 2
                    )),
                    with: .color(Color.vbPink.opacity(alpha * 0.45))
                )
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: – Brain View (Main)

struct BrainView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var selectedNoteID: String?
    @State private var showNoteSheet   = false
    @State private var longPressNodeID: String?
    @State private var showLongPress   = false
    @State private var showStatusIndicators = true
    @State private var showCaptureSheet = false
    @State private var isToolbarSearchExpanded = false
    @State private var toolbarSearchText = ""
    @State private var toolbarSearchCategory: ToolbarSearchCategory?
    @State private var captureToast: CaptureToast?
    @State private var mutatingNoteID: String?

    var body: some View {
        ZStack(alignment: .top) {
            CosmicBackgroundView()

            if viewModel.graphModel.nodes.isEmpty && !viewModel.graphModel.isLoading {
                emptyState
            } else {
                BrainGraphView(
                    nodes: viewModel.graphModel.nodes,
                    edges: viewModel.graphModel.edges,
                    selectedNodeID: selectedNoteID,
                    toolbarSearchExpanded: isToolbarSearchExpanded,
                    highlightedNodeIDs: toolbarHighlightedNodeIDs,
                    onNodeTapped: { id in
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                            selectedNoteID = id
                        }
                    },
                    onNodeOpened: { id in
                        selectedNoteID = id
                        showNoteSheet = true
                    },
                    onNodeLongPressed: { id in
                        longPressNodeID = id
                        selectedNoteID  = id
                        withAnimation(.spring(duration: 0.35)) { showLongPress = true }
                    },
                    onBackgroundTapped: {
                        withAnimation(.easeInOut(duration: 0.28)) { selectedNoteID = nil }
                    },
                    showStatusIndicators: showStatusIndicators
                )
                .ignoresSafeArea()
            }

            if viewModel.graphModel.isLoading {
                LoadingUniverseView(progress: viewModel.graphModel.loadingProgress)
                    .ignoresSafeArea()
                    .zIndex(50)
            }

            if let err = viewModel.graphModel.errorMessage {
                ErrorBannerView(message: err) { Task { await viewModel.loadNotes() } }
                    .padding(.top, 60)
                    .zIndex(30)
            }

            ToolbarPillView(
                noteCount: viewModel.graphModel.nodes.count,
                linkCount: viewModel.graphModel.edges.count,
                isLoading: viewModel.graphModel.isLoading,
                showStatusIndicators: showStatusIndicators,
                isSearchExpanded: $isToolbarSearchExpanded,
                searchText: $toolbarSearchText,
                selectedSearchCategory: $toolbarSearchCategory,
                highlightedCount: toolbarHighlightedNodeIDs?.count,
                onToggleStatusIndicators: {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        showStatusIndicators.toggle()
                    }
                },
                onCapture: { showCaptureSheet = true },
                onCaptureToday: { Task { await openTodayNote() } },
                onSearch: {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                        isToolbarSearchExpanded.toggle()
                        if !isToolbarSearchExpanded {
                            toolbarSearchText = ""
                            toolbarSearchCategory = nil
                        }
                    }
                },
                onRefresh: { Task { await viewModel.loadNotes() } },
                onLogout:  { viewModel.logout() }
            )
            .zIndex(20)
        }
        .overlay(alignment: .top) {
            if let captureToast {
                CaptureToastView(toast: captureToast)
                    .padding(.top, 106)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(40)
            }
        }
        .overlay(alignment: .bottom) {
            if !showLongPress,
               let node = selectedNode {
                NodeInsightPanelView(
                    node: node,
                    outgoingNodes: selectedOutgoingNodes,
                    incomingNodes: selectedIncomingNodes,
                    isMutating: mutatingNoteID == node.id,
                    onSelectNode: { id in
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.82)) {
                            selectedNoteID = id
                        }
                    },
                    onOpen: { showNoteSheet = true },
                    onCopyWikilink: { UIPasteboard.general.string = "[[\(node.title)]]" },
                    onRename: { title in
                        Task { await renameSelectedNode(nodeID: node.id, title: title) }
                    },
                    onDelete: {
                        Task { await deleteSelectedNode(nodeID: node.id) }
                    },
                    onClose: {
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                            selectedNoteID = nil
                        }
                    }
                )
                .padding(.horizontal, 14)
                .padding(.bottom, 22)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(25)
            }
        }
        .overlay {
            if showLongPress,
               let nodeID = longPressNodeID,
               let node   = viewModel.graphModel.nodes.first(where: { $0.id == nodeID }) {
                LongPressMenuView(
                    node: node,
                    connectedCount: node.connectionCount,
                    onOpen: {
                        withAnimation(.spring(duration: 0.28)) { showLongPress = false }
                        showNoteSheet = true
                    },
                    onCopyWikilink: {
                        UIPasteboard.general.string = "[[\(node.title)]]"
                        withAnimation(.spring(duration: 0.28)) { showLongPress = false }
                    },
                    onDismiss: {
                        withAnimation(.spring(duration: 0.35)) { showLongPress = false }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: showLongPress)
        .sheet(isPresented: $showNoteSheet) {
            if let id = selectedNoteID {
                NoteView(noteID: id).environmentObject(viewModel)
            }
        }
        .sheet(isPresented: $showCaptureSheet) {
            CaptureSheet(
                onCreated: { _ in showToast("Note erstellt") },
                onError: { message in showToast(message, isError: true) }
            )
            .environmentObject(viewModel)
            .presentationDetents([.medium, .large])
        }
        .task {
            if viewModel.graphModel.nodes.isEmpty {
                await viewModel.loadNotes()
            }
        }
    }

    private var toolbarHighlightedNodeIDs: Set<String>? {
        guard isToolbarSearchExpanded else { return nil }
        let query = toolbarSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty || toolbarSearchCategory != nil else { return nil }

        let matches = viewModel.graphModel.nodes.filter { node in
            let categoryMatches = toolbarSearchCategory?.matches(node) ?? true
            let queryMatches = query.isEmpty
                || node.title.lowercased().contains(query)
                || node.id.lowercased().contains(query)
            return categoryMatches && queryMatches
        }
        return Set(matches.map(\.id))
    }

    private var selectedNode: GraphNode? {
        guard let selectedNoteID else { return nil }
        return viewModel.graphModel.nodes.first { $0.id == selectedNoteID }
    }

    private var selectedOutgoingNodes: [GraphNode] {
        guard let node = selectedNode else { return [] }
        return nodes(for: node.outgoingLinks)
    }

    private var selectedIncomingNodes: [GraphNode] {
        guard let node = selectedNode else { return [] }
        return nodes(for: node.incomingLinks)
    }

    private func nodes(for ids: Set<String>) -> [GraphNode] {
        viewModel.graphModel.nodes
            .filter { ids.contains($0.id) }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func openTodayNote() async {
        do {
            let path = try await viewModel.createOrOpenTodayNote()
            await MainActor.run {
                selectedNoteID = path
                showNoteSheet = true
                showToast("Daily Note bereit")
            }
        } catch {
            await MainActor.run { showToast(error.localizedDescription, isError: true) }
        }
    }

    private func renameSelectedNode(nodeID: String, title: String) async {
        guard mutatingNoteID == nil else { return }
        mutatingNoteID = nodeID
        do {
            let newPath = try await viewModel.renameNote(path: nodeID, to: title)
            await MainActor.run {
                selectedNoteID = newPath
                showToast("Note umbenannt")
            }
        } catch {
            await MainActor.run { showToast(error.localizedDescription, isError: true) }
        }
        await MainActor.run { mutatingNoteID = nil }
    }

    private func deleteSelectedNode(nodeID: String) async {
        guard mutatingNoteID == nil else { return }
        mutatingNoteID = nodeID
        do {
            try await viewModel.deleteNote(path: nodeID)
            await MainActor.run {
                selectedNoteID = nil
                showToast("Note gelöscht")
            }
        } catch {
            await MainActor.run { showToast(error.localizedDescription, isError: true) }
        }
        await MainActor.run { mutatingNoteID = nil }
    }

    private func showToast(_ message: String, isError: Bool = false) {
        let toast = CaptureToast(message: message, isError: isError)
        withAnimation(.spring(response: 0.30, dampingFraction: 0.86)) {
            captureToast = toast
        }
        Task {
            try? await Task.sleep(for: .seconds(isError ? 3.2 : 2.1))
            await MainActor.run {
                guard captureToast?.id == toast.id else { return }
                withAnimation(.easeOut(duration: 0.22)) {
                    captureToast = nil
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            PearlView(size: 72)
            Text("Tippe ↺ zum Synchronisieren")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .italic()
                .foregroundColor(.vbFg3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct CaptureToast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let isError: Bool
}

private enum ToolbarSearchCategory: String, CaseIterable, Identifiable {
    case projects
    case concepts
    case daily
    case inbox
    case wip
    case done
    case evergreen

    var id: String { rawValue }

    var title: String {
        switch self {
        case .projects: return "Projects"
        case .concepts: return "Concepts"
        case .daily: return "Daily"
        case .inbox: return "Inbox"
        case .wip: return "wip"
        case .done: return "done"
        case .evergreen: return "evergreen"
        }
    }

    var tint: Color {
        switch self {
        case .wip, .done, .evergreen: return statusColor(rawValue)
        default: return .vbPink
        }
    }

    func matches(_ node: GraphNode) -> Bool {
        let path = node.id.lowercased()
        switch self {
        case .projects: return path.hasPrefix("projects/") || node.frontmatter?.type?.lowercased() == "project"
        case .concepts: return path.hasPrefix("concepts/") || node.frontmatter?.type?.lowercased() == "concept"
        case .daily: return path.hasPrefix("daily/")
        case .inbox: return path.hasPrefix("inbox/")
        case .wip, .done, .evergreen: return node.frontmatter?.status?.lowercased() == rawValue
        }
    }
}

private struct CaptureToastView: View {
    let toast: CaptureToast

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toast.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(toast.isError ? .vbDanger : .vbSuccess)
            Text(toast.message)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.vbFg1)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke((toast.isError ? Color.vbDanger : Color.vbSuccess).opacity(0.24), lineWidth: 1))
        .shadow(color: Color.vbPink.opacity(0.14), radius: 18, y: 8)
        .padding(.horizontal, 18)
    }
}

// MARK: – Toolbar Pill

struct LiquidGlassPanel: View {
    let cornerRadius: CGFloat
    var tint: Color = .vbPink
    var opacity: Double = 0.70

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(opacity), tint.opacity(0.10), Color.white.opacity(0.30)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.78), tint.opacity(0.28), Color.white.opacity(0.42)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: tint.opacity(0.14), radius: 22, y: 10)
    }
}

private struct LiquidGlassCircle: View {
    let tint: Color
    let isActive: Bool

    var body: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay(Circle().fill(Color.white.opacity(isActive ? 0.52 : 0.34)))
            .overlay(Circle().stroke(tint.opacity(isActive ? 0.52 : 0.20), lineWidth: 1.2))
            .shadow(color: tint.opacity(isActive ? 0.20 : 0.08), radius: isActive ? 14 : 8, y: 5)
    }
}

private struct ToolbarPillView: View {
    let noteCount: Int
    let linkCount: Int
    let isLoading: Bool
    let showStatusIndicators: Bool
    @Binding var isSearchExpanded: Bool
    @Binding var searchText: String
    @Binding var selectedSearchCategory: ToolbarSearchCategory?
    let highlightedCount: Int?
    let onToggleStatusIndicators: () -> Void
    let onCapture: () -> Void
    let onCaptureToday: () -> Void
    let onSearch: () -> Void
    let onRefresh: () -> Void
    let onLogout:  () -> Void

    @FocusState private var isSearchFocused: Bool
    @State private var didLongPressCapture = false

    var body: some View {
        VStack(alignment: .leading, spacing: isSearchExpanded ? 12 : 10) {
            HStack(spacing: 10) {
                PearlView(size: 30)
                    .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Synaptic Vault")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.vbFg1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    Text("\(noteCount) Nodes · \(linkCount) Synapsen")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.vbFg3)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .monospacedDigit()
                }

                Spacer(minLength: 8)
            }

            HStack(spacing: 10) {
                Spacer(minLength: 0)
                captureButton
                pillButton(icon: showStatusIndicators ? "circlebadge.fill" : "circlebadge", tint: .vbFg2, isActive: showStatusIndicators, action: onToggleStatusIndicators)
                pillButton(icon: isSearchExpanded ? "xmark" : "magnifyingglass", tint: .vbPink, isActive: isSearchExpanded, action: onSearch)
                pillButton(icon: "arrow.clockwise", tint: .vbFg2, isActive: false, action: onRefresh)
                    .disabled(isLoading)
                    .opacity(isLoading ? 0.50 : 1.0)
                pillButton(icon: "person.slash", tint: .vbDanger, isActive: false, action: onLogout)
            }

            if isSearchExpanded {
                searchIsland
                    .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.98, anchor: .top)))
            }
        }
        .padding(.vertical, isSearchExpanded ? 14 : 12)
        .padding(.horizontal, 16)
        .background {
            LiquidGlassPanel(cornerRadius: isSearchExpanded ? 34 : 30, tint: .vbPink, opacity: isSearchExpanded ? 0.62 : 0.70)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: isSearchExpanded)
        .onChange(of: isSearchExpanded) { _, expanded in
            if !expanded {
                isSearchFocused = false
            }
        }
    }

    private var searchIsland: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.vbFg3)
                TextField("Find note", text: $searchText)
                    .focused($isSearchFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .foregroundColor(.vbFg1)
                    .font(.system(size: 14, weight: .medium, design: .rounded))

                if let highlightedCount, (!searchText.isEmpty || selectedSearchCategory != nil) {
                    Text("\(highlightedCount)")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(.vbPink)
                        .monospacedDigit()
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.46))
                        .clipShape(Capsule())
                }

                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.vbFg4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background { LiquidGlassPanel(cornerRadius: 14, tint: .vbLavender, opacity: 0.42) }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ToolbarSearchChip(title: "Alle", tint: .vbPink, isSelected: selectedSearchCategory == nil) {
                        selectedSearchCategory = nil
                    }
                    ForEach(ToolbarSearchCategory.allCases) { category in
                        ToolbarSearchChip(title: category.title, tint: category.tint, isSelected: selectedSearchCategory == category) {
                            selectedSearchCategory = selectedSearchCategory == category ? nil : category
                        }
                    }
                }
                .padding(.horizontal, 1)
                .padding(.vertical, 2)
            }
        }
    }

    private var captureButton: some View {
        Button {
            if didLongPressCapture {
                didLongPressCapture = false
                return
            }
            onCapture()
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.vbPink)
                .frame(width: 36, height: 36)
                .background { LiquidGlassCircle(tint: .vbPink, isActive: false) }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.48)
                .onEnded { _ in
                    didLongPressCapture = true
                    onCaptureToday()
                    Task {
                        try? await Task.sleep(for: .milliseconds(650))
                        await MainActor.run { didLongPressCapture = false }
                    }
                }
        )
    }

    private func pillButton(icon: String, tint: Color, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(isActive ? tint : .vbFg2)
                .frame(width: 36, height: 36)
                .background { LiquidGlassCircle(tint: tint, isActive: isActive) }
        }
        .buttonStyle(.plain)
    }
}

private struct ToolbarSearchChip: View {
    let title: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(isSelected ? .white : .vbFg2)
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(Capsule().fill(isSelected ? tint.opacity(0.82) : Color.white.opacity(0.34)))
                        .overlay(Capsule().stroke(tint.opacity(isSelected ? 0.0 : 0.24), lineWidth: 1))
                }
        }
        .buttonStyle(.plain)
    }
}

// MARK: – Node Insight Panel

private struct NodeInsightPanelView: View {
    let node: GraphNode
    let outgoingNodes: [GraphNode]
    let incomingNodes: [GraphNode]
    let isMutating: Bool
    let onSelectNode: (String) -> Void
    let onOpen: () -> Void
    let onCopyWikilink: () -> Void
    let onRename: (String) -> Void
    let onDelete: () -> Void
    let onClose: () -> Void

    @State private var didCopy = false
    @State private var showRenameAlert = false
    @State private var showDeleteAlert = false
    @State private var renameTitle = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                PearlView(size: 34)
                    .frame(width: 38, height: 38)
                    .shadow(color: .vbMagenta.opacity(0.42), radius: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(node.title)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(.vbFg1)
                        .lineLimit(1)
                    Text("\(outgoingNodes.count) raus · \(incomingNodes.count) rein")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.vbFg3)
                        .monospacedDigit()
                }

                Spacer()

                insightButton(icon: didCopy ? "checkmark" : "doc.on.doc", tint: didCopy ? .vbSuccess : .vbLavender) {
                    onCopyWikilink()
                    withAnimation(.spring(response: 0.24, dampingFraction: 0.78)) { didCopy = true }
                    Task {
                        try? await Task.sleep(for: .seconds(1.4))
                        await MainActor.run {
                            withAnimation(.easeOut(duration: 0.2)) { didCopy = false }
                        }
                    }
                }
                insightButton(icon: "arrow.up.right", tint: .vbPink, action: onOpen)
                actionsMenu
                insightButton(icon: "xmark", tint: .vbFg3, action: onClose)
            }

            if node.frontmatter?.hasValues == true {
                frontmatterChips
            }

            linkSection(title: "Verweist auf", nodes: outgoingNodes, color: .vbPink)
            linkSection(title: "Wird referenziert von", nodes: incomingNodes, color: .vbLavender)
        }
        .padding(14)
        .onAppear { renameTitle = node.title }
        .onChange(of: node.id) { _, _ in renameTitle = node.title }
        .alert("Node umbenennen", isPresented: $showRenameAlert) {
            TextField("Name", text: $renameTitle)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Abbrechen", role: .cancel) { renameTitle = node.title }
            Button("Sichern") { onRename(renameTitle) }
                .disabled(renameTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Der Dateiname wird angepasst und die erste Überschrift wird aktualisiert.")
        }
        .alert("Node löschen?", isPresented: $showDeleteAlert) {
            Button("Löschen", role: .destructive, action: onDelete)
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Diese Note wird aus dem GitHub-Vault gelöscht. Das kann nicht direkt in der App rückgängig gemacht werden.")
        }
        .opacity(isMutating ? 0.72 : 1.0)
        .allowsHitTesting(!isMutating)
    }

    private var actionsMenu: some View {
        Menu {
            Button {
                renameTitle = node.title
                showRenameAlert = true
            } label: {
                Label("Umbenennen", systemImage: "pencil")
            }

            Button(role: .destructive) {
                showDeleteAlert = true
            } label: {
                Label("Löschen", systemImage: "trash")
            }
        } label: {
            Image(systemName: isMutating ? "hourglass" : "ellipsis")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.vbFg2)
                .frame(width: 34, height: 34)
                .background { LiquidGlassCircle(tint: .vbFg2, isActive: false) }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func linkSection(title: String, nodes: [GraphNode], color: Color) -> some View {
        if !nodes.isEmpty {
            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.vbFg2)
                    Text("\(nodes.count)")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                        .monospacedDigit()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background {
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .overlay(Capsule().fill(color.opacity(0.12)))
                        }
                        .clipShape(Capsule())
                    Spacer()
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(nodes.prefix(10)) { linkedNode in
                            Button {
                                onSelectNode(linkedNode.id)
                            } label: {
                                Text(linkedNode.title)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.vbFg2)
                                    .lineLimit(1)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background {
                                        Capsule()
                                            .fill(.ultraThinMaterial)
                                            .overlay(Capsule().fill(color.opacity(0.12)))
                                    }
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(color.opacity(0.28), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func insightButton(icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(tint)
                .frame(width: 34, height: 34)
                .background { LiquidGlassCircle(tint: tint, isActive: false) }
        }
        .buttonStyle(.plain)
    }

    private var frontmatterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                if let type = node.frontmatter?.type {
                    metadataChip(label: type, color: nodeTypeColor(type) ?? .vbLavender)
                }
                if let status = node.frontmatter?.status {
                    metadataChip(label: status, color: statusColor(status))
                }
                if let updated = node.frontmatter?.updated {
                    metadataChip(label: updated, color: .vbFg3)
                }
            }
        }
    }

    private func metadataChip(label: String, color: Color) -> some View {
        Text(label)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.vbFg2)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().fill(color.opacity(0.13)))
            }
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.34), lineWidth: 1))
    }
}

// MARK: – 3D Graph

struct BrainGraphView: View {
    let nodes: [GraphNode]
    let edges: [GraphEdge]
    let selectedNodeID: String?
    let toolbarSearchExpanded: Bool
    let highlightedNodeIDs: Set<String>?
    let onNodeTapped:      (String) -> Void
    let onNodeOpened:      (String) -> Void
    let onNodeLongPressed: (String) -> Void
    let onBackgroundTapped: () -> Void
    let showStatusIndicators: Bool

    @State private var zoom: CGFloat = 1.0
    @State private var graphOffset: CGSize = .zero
    @State private var focusZoom: CGFloat = 1.0
    @State private var stickyFocusNodeID: String?
    @State private var pinchBaseZoom: CGFloat?
    @State private var pinchBaseOffset: CGSize = .zero
    // User-controlled rotation (drag to spin)
    @State private var userRotY: Double = 0
    @State private var userRotX: Double = 0
    @GestureState private var dragDelta: CGSize = .zero

    private var connectedIDs: Set<String> {
        guard let sel = selectedNodeID,
              let node = nodes.first(where: { $0.id == sel }) else { return [] }
        return node.outgoingLinks.union(node.incomingLinks)
    }

    var body: some View {
        GeometryReader { geo in
            let currentZoom = zoom * focusZoom
            let rotY  = userRotY - dragDelta.width * 0.004
            let rotX  = 0.22 + userRotX - dragDelta.height * 0.003
            let isInteracting = dragDelta != .zero || pinchBaseZoom != nil
                let clampX = max(-0.55, min(0.55, rotX))
                let selID     = selectedNodeID
                let projectionFocusID = selID ?? stickyFocusNodeID
                let connected = connectedIDs

                let projected = computeProjections(
                    rotY: rotY,
                    rotX: clampX,
                    size: geo.size,
                    zoom: currentZoom,
                    graphOffset: graphOffset,
                    focusNodeID: projectionFocusID
                )
                let idToPos   = Dictionary(uniqueKeysWithValues: projected.map { ($0.id, $0) })
                let nodeByID = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
                let sortedProjected = projected.sorted { $0.z < $1.z }
                let backgroundNodes = sortedProjected.filter { item in
                    guard let selID else { return true }
                    return item.id != selID && !connected.contains(item.id)
                }
                let foregroundNodes = sortedProjected.filter { item in
                    guard let selID else { return false }
                    return item.id == selID || connected.contains(item.id)
                }

                ZStack {
                    // Background tap target clears selection.
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { onBackgroundTapped() }

                    DeepSpaceGridView(selectedNodeID: selID)
                        .allowsHitTesting(false)

                    Canvas { ctx, _ in
                        drawConstellationEdges(
                            ctx: &ctx,
                            projected: projected,
                            idToPos: idToPos,
                            nodeByID: nodeByID,
                            connected: connected,
                            selectedID: selID,
                            highlightedNodeIDs: highlightedNodeIDs,
                            isInteracting: isInteracting,
                            layer: .background
                        )
                    }
                    .allowsHitTesting(false)

                    // Background nodes: unconnected notes sit behind the glass layer.
                    ForEach(backgroundNodes) { item in
                        nodeView(for: item, selectedID: selID, connected: connected, highlightedNodeIDs: highlightedNodeIDs, reduceEffects: isInteracting)
                            .position(item.screenPos)
                    }

                    if selID != nil {
                        GraphGlassVeilView(reduceEffects: isInteracting)
                            .allowsHitTesting(false)
                            .transition(.opacity.combined(with: .scale(scale: 1.015)))

                        Canvas { ctx, _ in
                            drawConstellationEdges(
                                ctx: &ctx,
                                projected: projected,
                                idToPos: idToPos,
                                nodeByID: nodeByID,
                                connected: connected,
                                selectedID: selID,
                                highlightedNodeIDs: highlightedNodeIDs,
                                isInteracting: isInteracting,
                                layer: .foreground
                            )
                        }
                        .allowsHitTesting(false)
                    }

                    // Foreground nodes: selection and direct connections stay crisp above glass.
                    ForEach(foregroundNodes) { item in
                        nodeView(for: item, selectedID: selID, connected: connected, highlightedNodeIDs: highlightedNodeIDs, reduceEffects: isInteracting)
                            .position(item.screenPos)
                    }
                }
            .animation(.spring(response: 0.74, dampingFraction: 0.88), value: selectedNodeID)
            .animation(.spring(response: 0.74, dampingFraction: 0.88), value: stickyFocusNodeID)
            .animation(.spring(response: 0.70, dampingFraction: 0.90), value: focusZoom)
            .gesture(
                magnifyGesture(in: geo.size)
                    .simultaneously(with: rotateGesture)
            )
            .onChange(of: selectedNodeID) { _, newValue in
                withAnimation(.spring(response: 0.74, dampingFraction: 0.88)) {
                    graphOffset = .zero
                    if let newValue {
                        stickyFocusNodeID = newValue
                        focusZoom = 1.12
                    } else {
                        focusZoom = 1.0
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func nodeView(for item: ProjectedNode, selectedID: String?, connected: Set<String>, highlightedNodeIDs: Set<String>?, reduceEffects: Bool) -> some View {
        let isSelected = item.id == selectedID
        let isSearchMatch = selectedID == nil && (highlightedNodeIDs?.contains(item.id) ?? false)
        let isNeighbor = connected.contains(item.id) || isSearchMatch
        let isSelectionDim = selectedID != nil && !isSelected && !isNeighbor
        let isSearchDim = selectedID == nil && highlightedNodeIDs != nil && !isSearchMatch
        let isDim = isSelectionDim || isSearchDim

        GirlyNodeView(
            node: item.node,
            isSelected: isSelected,
            isNeighbor: isNeighbor,
            isDim: isDim,
            depthScale: item.depthScale,
            highlightVector: item.highlightVector,
            highlightOpacity: item.highlightOpacity,
            showStatusIndicator: showStatusIndicators,
            orbitalPhase: phaseSeed(item.id),
            reduceEffects: reduceEffects,
            onTap: onNodeTapped,
            onOpen: onNodeOpened,
            onLongPress: onNodeLongPressed
        )
    }

    // MARK: Projected node data

    private struct ProjectedNode: Identifiable {
        let id: String
        let node: GraphNode
        let screenPos: CGPoint
        let depthScale: CGFloat
        let highlightVector: CGVector
        let highlightOpacity: Double
        let z: Float

        func isDimmed(selID: String?, connected: Set<String>) -> Bool {
            guard let s = selID else { return false }
            return id != s && !connected.contains(id)
        }
    }

    private func computeProjections(
        rotY: Double,
        rotX: Double,
        size: CGSize,
        zoom: CGFloat,
        graphOffset: CGSize,
        focusNodeID: String?
    ) -> [ProjectedNode] {
        let viewport = graphViewport(in: size)
        let lightVector = sceneLightVector(rotY: rotY, rotX: rotX)
        let viewVector = SIMD3<Float>(0, 0, 1)
        let rawItems = nodes.map { node in
            let p = rotate3D(node.position, rotY: rotY, rotX: rotX)
            let f = depthFactor(for: p)
            let rawPos = CGPoint(x: CGFloat(p.x) * f, y: -CGFloat(p.y) * f)
            let perspectiveScale = max(0.58, min(1.78, pow(Double(f), 1.16)))
            let depthScale = CGFloat(perspectiveScale) * sqrt(zoom)
            let nodeNormal = normalized(SIMD3<Float>(p.x * 0.16, p.y * 0.16, p.z * 0.16 + 1.18))
            let diffuse = max(0, simd_dot(nodeNormal, lightVector))
            let reflection = normalized(2 * diffuse * nodeNormal - lightVector)
            let specular = pow(max(0, simd_dot(reflection, viewVector)), 7.0)
            let highlight = normalized(lightVector * 0.76 + nodeNormal * 0.24)
            let highlightVector = CGVector(
                dx: CGFloat(max(-0.86, min(0.86, highlight.x))),
                dy: CGFloat(max(-0.86, min(0.86, -highlight.y)))
            )
            let highlightOpacity = Double(max(0.14, min(0.48, 0.15 + 0.18 * diffuse + 0.22 * specular)))
            return (node: node, rawPos: rawPos, depthScale: depthScale, highlightVector: highlightVector, highlightOpacity: highlightOpacity, z: p.z)
        }

        guard !rawItems.isEmpty else { return [] }

        let minX = rawItems.map(\.rawPos.x).min() ?? 0
        let maxX = rawItems.map(\.rawPos.x).max() ?? 0
        let minY = rawItems.map(\.rawPos.y).min() ?? 0
        let maxY = rawItems.map(\.rawPos.y).max() ?? 0
        let rawCenter = CGPoint(x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        let rawWidth = max(maxX - minX, 1.0)
        let rawHeight = max(maxY - minY, 1.0)

        let xScale = (viewport.width * 0.90 / rawWidth) * zoom
        let yScale = (viewport.height * 0.86 / rawHeight) * zoom

        let projected = rawItems.map { item in
            let pos = CGPoint(
                x: viewport.midX + (item.rawPos.x - rawCenter.x) * xScale,
                y: viewport.midY + (item.rawPos.y - rawCenter.y) * yScale
            )
            return ProjectedNode(
                id: item.node.id,
                node: item.node,
                screenPos: pos,
                depthScale: item.depthScale,
                highlightVector: item.highlightVector,
                highlightOpacity: item.highlightOpacity,
                z: item.z
            )
        }

        guard let focusNodeID,
              let focus = projected.first(where: { $0.id == focusNodeID }) else {
            return applyGraphOffset(to: projected, offset: graphOffset)
        }

        let center = CGPoint(x: viewport.midX, y: viewport.midY)
        let focusOffset = CGSize(
            width: center.x - focus.screenPos.x,
            height: center.y - focus.screenPos.y
        )

        return applyGraphOffset(
            to: projected.map { item in
                ProjectedNode(
                    id: item.id,
                    node: item.node,
                    screenPos: CGPoint(
                        x: item.screenPos.x + focusOffset.width,
                        y: item.screenPos.y + focusOffset.height
                    ),
                    depthScale: item.depthScale,
                    highlightVector: item.highlightVector,
                    highlightOpacity: item.highlightOpacity,
                    z: item.z
                )
            },
            offset: graphOffset
        )
    }

    // Rotate SCNVector3 around Y then X axis
    private func rotate3D(_ pos: SCNVector3, rotY: Double, rotX: Double) -> SIMD3<Float> {
        rotateVector3D(SIMD3<Float>(pos.x, pos.y, pos.z), rotY: rotY, rotX: rotX)
    }

    private func rotateVector3D(_ pos: SIMD3<Float>, rotY: Double, rotX: Double) -> SIMD3<Float> {
        let cosY = Float(cos(rotY)), sinY = Float(sin(rotY))
        let x1   = pos.x * cosY + pos.z * sinY
        let z1   = -pos.x * sinY + pos.z * cosY

        let cosX = Float(cos(rotX)), sinX = Float(sin(rotX))
        let y2   = pos.y * cosX - z1 * sinX
        let z2   = pos.y * sinX + z1 * cosX

        return SIMD3<Float>(x1, y2, z2)
    }

    private func sceneLightVector(rotY: Double, rotX: Double) -> SIMD3<Float> {
        // World-space key light: above-left-front, then rotated with the brain volume.
        normalized(rotateVector3D(SIMD3<Float>(-0.72, 0.86, 0.42), rotY: rotY * 0.82, rotX: rotX * 0.74))
    }

    private func applyGraphOffset(to projected: [ProjectedNode], offset: CGSize) -> [ProjectedNode] {
        projected.map { item in
            ProjectedNode(
                id: item.id,
                node: item.node,
                screenPos: CGPoint(
                    x: item.screenPos.x + offset.width,
                    y: item.screenPos.y + offset.height
                ),
                depthScale: item.depthScale,
                highlightVector: item.highlightVector,
                highlightOpacity: item.highlightOpacity,
                z: item.z
            )
        }
    }

    private func normalized(_ value: SIMD3<Float>) -> SIMD3<Float> {
        let length = max(simd_length(value), 0.0001)
        return value / length
    }

    private var rotateGesture: some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { _ in releaseStickyFocusIfNeeded() }
            .updating($dragDelta) { v, s, _ in s = v.translation }
            .onEnded { v in
                let predictedX = v.predictedEndTranslation.width - v.translation.width
                let predictedY = v.predictedEndTranslation.height - v.translation.height
                userRotY -= (v.translation.width + predictedX * 0.28) * 0.004
                userRotX  = max(-0.55, min(0.55,
                    userRotX - (v.translation.height + predictedY * 0.22) * 0.003))
            }
    }

    private func releaseStickyFocusIfNeeded() {
        guard selectedNodeID == nil, stickyFocusNodeID != nil else { return }
        withAnimation(.spring(response: 0.58, dampingFraction: 0.88)) {
            stickyFocusNodeID = nil
        }
    }

    private func magnifyGesture(in size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                if pinchBaseZoom == nil {
                    releaseStickyFocusIfNeeded()
                    pinchBaseZoom = zoom
                    pinchBaseOffset = graphOffset
                }

                let baseZoom = pinchBaseZoom ?? zoom
                let nextZoom = max(0.45, min(3.4, baseZoom * value.magnification))
                let scaleRatio = nextZoom / max(baseZoom, 0.0001)
                let viewport = graphViewport(in: size)
                let anchor = clamp(value.startLocation, to: viewport)

                zoom = nextZoom
                graphOffset = anchoredOffset(
                    baseOffset: pinchBaseOffset,
                    anchor: anchor,
                    center: CGPoint(x: viewport.midX, y: viewport.midY),
                    scaleRatio: scaleRatio
                )
            }
            .onEnded { _ in
                pinchBaseZoom = nil
                pinchBaseOffset = graphOffset
            }
    }

    private func anchoredOffset(
        baseOffset: CGSize,
        anchor: CGPoint,
        center: CGPoint,
        scaleRatio: CGFloat
    ) -> CGSize {
        CGSize(
            width: (anchor.x - center.x) - scaleRatio * (anchor.x - center.x - baseOffset.width),
            height: (anchor.y - center.y) - scaleRatio * (anchor.y - center.y - baseOffset.height)
        )
    }

    private func clamp(_ point: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(
            x: max(rect.minX, min(rect.maxX, point.x)),
            y: max(rect.minY, min(rect.maxY, point.y))
        )
    }

    private func graphViewport(in size: CGSize) -> CGRect {
        let hasPinnedFocus = selectedNodeID != nil || stickyFocusNodeID != nil
        let topInset = toolbarSearchExpanded
            ? min(max(size.height * 0.39, 318), 390)
            : min(max(size.height * 0.25, 208), 242)
        let bottomInset = hasPinnedFocus
            ? min(max(size.height * 0.36, 306), 372)
            : min(max(size.height * 0.18, 142), 188)
        let horizontalInset: CGFloat = 28
        let labelAndPearlPadding: CGFloat = hasPinnedFocus ? 18 : 28
        return CGRect(
            x: horizontalInset,
            y: topInset + labelAndPearlPadding,
            width: max(1, size.width - horizontalInset * 2),
            height: max(1, size.height - topInset - bottomInset - labelAndPearlPadding * 2)
        )
    }

    private func depthFactor(for p: SIMD3<Float>) -> CGFloat {
        let cam: Float = 22.0
        let dz = cam - p.z
        return CGFloat(cam / max(dz, 4.0))
    }

    private func baseRadius(_ node: GraphNode) -> CGFloat {
        structuredNodeBaseRadius(node)
    }

    private enum GraphLayer {
        case background
        case foreground
    }

    private enum FocusedEdgeKind {
        case outgoing
        case incoming
        case bidirectional
    }

    private func drawConstellationEdges(
        ctx: inout GraphicsContext,
        projected: [ProjectedNode],
        idToPos: [String: ProjectedNode],
        nodeByID: [String: GraphNode],
        connected: Set<String>,
        selectedID: String?,
        highlightedNodeIDs: Set<String>?,
        isInteracting: Bool,
        layer: GraphLayer
    ) {
        for edge in edges {
            guard let a = idToPos[edge.sourceID],
                  let b = idToPos[edge.targetID] else { continue }

            let focusedKind = edgeKind(edge, selectedID: selectedID, nodeByID: nodeByID)
            let isLit = focusedKind != nil && selectedID != nil
            if selectedID != nil {
                if layer == .background && isLit { continue }
                if layer == .foreground && !isLit { continue }
                if focusedKind == .bidirectional && edge.targetID == selectedID { continue }
            } else if layer == .foreground {
                continue
            }

            let kind = focusedKind ?? .bidirectional
            let depthFade = Double((a.depthScale + b.depthScale) / 2.0)
            let aHighlighted = highlightedNodeIDs?.contains(a.id) ?? false
            let bHighlighted = highlightedNodeIDs?.contains(b.id) ?? false
            let alpha: Double
            if selectedID == nil, highlightedNodeIDs != nil {
                alpha = aHighlighted && bHighlighted ? 0.34 : ((aHighlighted || bHighlighted) ? 0.08 : 0.018)
            } else {
                alpha = selectedID == nil ? 0.18 : (isLit ? 0.86 : 0.030)
            }
            let color: Color = selectedID == nil && highlightedNodeIDs != nil
                ? ((aHighlighted && bHighlighted) ? .vbPink : .vbLavender)
                : edgeColor(kind: kind, isFocused: isLit)
            drawEdge(
                ctx: &ctx,
                from: a.screenPos,
                to: b.screenPos,
                kind: kind,
                color: color,
                alpha: alpha * depthFade,
                isFocused: isLit
            )
        }

        guard layer == .foreground || selectedID == nil else { return }

        for item in projected where !item.isDimmed(selID: selectedID, connected: connected) {
            let isHighlighted = highlightedNodeIDs?.contains(item.id) ?? false
            if selectedID == nil, highlightedNodeIDs != nil, !isHighlighted { continue }
            let shouldLabel = item.id == selectedID || connected.contains(item.id) || isHighlighted || (selectedID == nil && item.depthScale > 0.92)
            guard shouldLabel else { continue }
            let r = baseRadius(item.node) * item.depthScale
            let title = String(item.node.title.prefix(item.id == selectedID ? 22 : 15))
            let label = ctx.resolve(
                Text(title)
                    .font(.system(size: max(8, CGFloat(item.id == selectedID ? 11 : 9) * item.depthScale), weight: .semibold))
                    .foregroundColor((item.id == selectedID || isHighlighted) ? .vbFg1 : .vbFg2.opacity(0.78))
            )
            ctx.draw(label,
                     at: CGPoint(x: item.screenPos.x, y: item.screenPos.y + r + 8),
                     anchor: .top)
        }
    }

    private func edgeKind(_ edge: GraphEdge, selectedID: String?, nodeByID: [String: GraphNode]) -> FocusedEdgeKind? {
        guard let selectedID else { return .bidirectional }
        guard edge.sourceID == selectedID || edge.targetID == selectedID,
              let focusedNode = nodeByID[selectedID] else { return nil }

        if edge.sourceID == selectedID {
            return focusedNode.incomingLinks.contains(edge.targetID) ? .bidirectional : .outgoing
        }
        if edge.targetID == selectedID {
            return focusedNode.outgoingLinks.contains(edge.sourceID) ? .bidirectional : .incoming
        }
        return nil
    }

    private func edgeColor(kind: FocusedEdgeKind, isFocused: Bool) -> Color {
        guard isFocused else { return .vbPink }
        switch kind {
        case .outgoing: return .vbPink
        case .incoming: return .vbLavender
        case .bidirectional: return .vbMagenta
        }
    }

    private func drawEdge(
        ctx: inout GraphicsContext,
        from start: CGPoint,
        to end: CGPoint,
        kind: FocusedEdgeKind,
        color: Color,
        alpha: Double,
        isFocused: Bool
    ) {
        guard isFocused else {
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            ctx.stroke(path, with: .color(color.opacity(alpha)), style: StrokeStyle(lineWidth: 0.75, lineCap: .round))
            return
        }

        switch kind {
        case .outgoing:
            drawTaperedLine(ctx: &ctx, from: start, to: end, color: color, alpha: alpha, startWidth: 3.2, endWidth: 0.8)
        case .incoming:
            drawTaperedLine(ctx: &ctx, from: start, to: end, color: color, alpha: alpha, startWidth: 0.8, endWidth: 3.2)
        case .bidirectional:
            var glow = Path()
            glow.move(to: start)
            glow.addLine(to: end)
            ctx.stroke(glow, with: .color(color.opacity(0.20 * alpha)), style: StrokeStyle(lineWidth: 8.0, lineCap: .round))
            ctx.stroke(glow, with: .color(color.opacity(alpha)), style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
        }
    }

    private func drawTaperedLine(
        ctx: inout GraphicsContext,
        from start: CGPoint,
        to end: CGPoint,
        color: Color,
        alpha: Double,
        startWidth: CGFloat,
        endWidth: CGFloat
    ) {
        let segments = 8
        for i in 0..<segments {
            let t0 = CGFloat(i) / CGFloat(segments)
            let t1 = CGFloat(i + 1) / CGFloat(segments)
            let p0 = interpolate(start, end, t0)
            let p1 = interpolate(start, end, t1)
            let width = startWidth + (endWidth - startWidth) * ((t0 + t1) / 2)
            var path = Path()
            path.move(to: p0)
            path.addLine(to: p1)
            ctx.stroke(path, with: .color(color.opacity(alpha)), style: StrokeStyle(lineWidth: width, lineCap: .round))
        }
    }

    private func interpolate(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    private func phaseSeed(_ value: String) -> Double {
        let total = value.unicodeScalars.reduce(0) { ($0 &* 31) &+ Int($1.value) }
        return Double(abs(total % 1_000)) / 1_000.0
    }
}

// MARK: – Spatial Grid

private struct DeepSpaceGridView: View {
    let selectedNodeID: String?

    var body: some View {
        Canvas { ctx, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxRadius = hypot(size.width, size.height) * 0.54
            let focusBoost = selectedNodeID == nil ? 0.0 : 0.012

            for i in 1...5 {
                let radius = maxRadius * CGFloat(i) / 5.6
                let rect = CGRect(
                    x: center.x - radius,
                    y: center.y - radius * 0.58,
                    width: radius * 2,
                    height: radius * 1.16
                )
                ctx.stroke(
                    Path(ellipseIn: rect),
                    with: .color(Color.vbLavender.opacity(0.018 + (i == 3 ? focusBoost : 0))),
                    lineWidth: 0.8
                )
            }

            for i in 0..<9 {
                let angle = Double(i) / 9.0 * Double.pi * 2.0
                let end = CGPoint(
                    x: center.x + cos(angle) * maxRadius,
                    y: center.y + sin(angle) * maxRadius * 0.58
                )
                var path = Path()
                path.move(to: center)
                path.addLine(to: end)
                ctx.stroke(path, with: .color(Color.vbPeriwinkle.opacity(0.018)), lineWidth: 0.7)
            }
        }
        .opacity(selectedNodeID == nil ? 0.65 : 1.0)
    }
}

private struct GraphGlassVeilView: View {
    let reduceEffects: Bool

    var body: some View {
        Rectangle()
            .fill(Color.white.opacity(reduceEffects ? 0.54 : 0.20))
            .overlay(
                LinearGradient(
                    colors: [Color.white.opacity(0.22), Color.vbDeep.opacity(0.18), Color.vbPink.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .background {
                if !reduceEffects {
                    Rectangle().fill(.ultraThinMaterial)
                }
            }
            .opacity(reduceEffects ? 0.72 : 0.82)
            .ignoresSafeArea()
    }
}

// MARK: – Node Dot

private func structuredNodeBaseRadius(_ node: GraphNode) -> CGFloat {
    let path = node.id.lowercased()
    let type = node.frontmatter?.type?.lowercased()
    let status = node.frontmatter?.status?.lowercased()

    let roleRadius: CGFloat
    if path.hasPrefix("daily/") || path.hasPrefix("inbox/") {
        roleRadius = 10.8
    } else {
        switch type {
        case "project", "portfolio", "goal":
            roleRadius = 14.2
        case "concept", "experiment", "person":
            roleRadius = 12.6
        case "reference":
            roleRadius = 11.4
        default:
            roleRadius = 11.8
        }
    }

    let incoming = node.incomingLinks.count
    let outgoing = node.outgoingLinks.count
    let hubBoost: CGFloat
    switch incoming {
    case 10...: hubBoost = 3.8
    case 5...: hubBoost = 2.4
    case 3...: hubBoost = 1.2
    default: hubBoost = 0
    }

    let activityBoost: CGFloat
    switch outgoing {
    case 6...: activityBoost = 1.2
    case 3...: activityBoost = 0.7
    case 1...: activityBoost = 0.3
    default: activityBoost = 0
    }

    let statusAdjustment: CGFloat = status == "archived" ? -1.1 : 0
    return max(9.8, min(18.4, roleRadius + hubBoost + activityBoost + statusAdjustment))
}

private struct GirlyNodeView: View {
    let node: GraphNode
    let isSelected: Bool
    let isNeighbor: Bool
    let isDim: Bool
    let depthScale: CGFloat   // perspective size modifier (0.5 – 1.5)
    let highlightVector: CGVector
    let highlightOpacity: Double
    let showStatusIndicator: Bool
    let orbitalPhase: TimeInterval
    let reduceEffects: Bool
    let onTap:       (String) -> Void
    let onOpen:      (String) -> Void
    let onLongPress: (String) -> Void

    @State private var rippleScale:   CGFloat = 0.8
    @State private var rippleOpacity: Double  = 0.0
    @State private var hubPulse: Double = 0.0

    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    private var baseR: CGFloat {
        structuredNodeBaseRadius(node) * depthScale
    }
    private var r: CGFloat { isSelected ? baseR * 1.62 : (isNeighbor ? baseR * 1.12 : baseR) }
    private var touchSize: CGFloat { max(52, r * 4.0) }

    private var pearlColors: [Color] {
        if let typeColor {
            return [.vbStardust, typeColor.opacity(0.42), typeColor.opacity(0.72), typeColor]
        }
        if isSelected {
            return [.vbStardust, .vbLilac, .vbRose, .vbPink, .vbMagenta]
        }
        let t = Double(min(node.connectionCount, 12)) / 12.0
        if t > 0.6 {
            return [.vbStardust, .vbLilac, .vbRose, .vbOrchid, .vbMagenta]
        }
        return [.vbStardust, .vbDeep, .vbPeriwinkle, .vbLilac, .vbLavender]
    }

    private var glowColor: Color {
        if isSelected { return .vbMagenta }
        if isNeighbor { return .vbPeriwinkle }
        return typeColor ?? .vbLavender
    }

    private var typeColor: Color? {
        nodeTypeColor(node.frontmatter?.type)
    }

    private var status: String? {
        node.frontmatter?.status
    }

    private var highlightCenter: UnitPoint {
        UnitPoint(
            x: max(0.18, min(0.82, 0.50 + highlightVector.dx * 0.28)),
            y: max(0.18, min(0.82, 0.50 + highlightVector.dy * 0.28))
        )
    }

    var body: some View {
        ZStack {
            if !reduceEffects && node.incomingLinks.count >= hubIncomingThreshold {
                Circle()
                    .stroke(Color.vbLavender.opacity(0.24 + hubPulse * 0.26), lineWidth: 1.2)
                    .frame(width: r * (4.1 + hubPulse * 0.55), height: r * (4.1 + hubPulse * 0.55))
                    .blur(radius: hubPulse * 0.8)
            }

            if !reduceEffects && (isSelected || isNeighbor) {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.clear, glowColor.opacity(0.20), .vbStardust.opacity(0.55), .clear],
                            center: .center
                        ),
                        lineWidth: isSelected ? 1.3 : 0.8
                    )
                    .frame(width: r * 4.3, height: r * 4.3)
                    .rotationEffect(.degrees(orbitalPhase * 24))
                    .opacity(isSelected ? 0.90 : 0.44)

                Circle()
                    .trim(from: 0.10, to: 0.22)
                    .stroke(Color.vbStardust.opacity(isSelected ? 0.72 : 0.38), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                    .frame(width: r * 5.0, height: r * 5.0)
                    .rotationEffect(.degrees(-orbitalPhase * 38))
            }

            // Outer aura
            if !reduceEffects && (isSelected || isNeighbor) {
                Circle()
                    .fill(glowColor.opacity(isSelected ? 0.0 : 0.12))
                    .frame(width: r * 4.0, height: r * 4.0)
                    .blur(radius: 8)
                    .animation(.easeInOut(duration: 0.3), value: isSelected)
            }

            // Ripple
            Circle()
                .stroke(Color.vbLavender.opacity(rippleOpacity), lineWidth: 1.5)
                .frame(width: r * rippleScale * 2, height: r * rippleScale * 2)

            // Inner halo
            if !reduceEffects && (isSelected || isNeighbor) {
                Circle()
                    .fill(glowColor.opacity(isSelected ? 0.0 : 0.16))
                    .frame(width: r * 2.5, height: r * 2.5)
                    .blur(radius: 6)
                    .animation(.easeInOut(duration: 0.3), value: isSelected)
            }

            // Pearl body
            Circle()
                .fill(
                    RadialGradient(
                        colors: pearlColors,
                        center: highlightCenter,
                        startRadius: 0, endRadius: r
                    )
                )
                .frame(width: r * 2, height: r * 2)

            // Specular highlight follows the current 3D rotation/light vector.
            Circle()
                .fill(Color.white.opacity(highlightOpacity))
                .frame(width: r * 0.40, height: r * 0.40)
                .offset(x: r * highlightVector.dx * 0.44, y: r * highlightVector.dy * 0.44)
                .blur(radius: reduceEffects ? 0 : r * 0.18)

            Circle()
                .stroke(Color.white.opacity(0.16), lineWidth: max(0.8, r * 0.04))
                .frame(width: r * 2, height: r * 2)
                .mask(
                    LinearGradient(
                        colors: [.clear, .white],
                        startPoint: UnitPoint(x: 0.5 - highlightVector.dx * 0.35, y: 0.5 - highlightVector.dy * 0.35),
                        endPoint: UnitPoint(x: 0.5 + highlightVector.dx * 0.35, y: 0.5 + highlightVector.dy * 0.35)
                    )
                )

            if !reduceEffects && showStatusIndicator, let status {
                StatusIndicatorView(status: status, radius: r)
                    .offset(x: r * 0.78, y: -r * 0.78)
            }
        }
        .frame(width: touchSize, height: touchSize)
        .saturation(isDim ? 0.36 : 1.0)
        .brightness(isDim ? 0.06 : 0.0)
        .blur(radius: reduceEffects ? 0.0 : (isDim ? 0.7 : 0.0))
        .scaleEffect(isSelected ? 1.04 : 1.0)
        .animation(.easeInOut(duration: 0.28), value: isDim)
        .animation(.easeInOut(duration: 0.28), value: isSelected)
        .contentShape(Circle())
        .onTapGesture {
            triggerRipple()
            haptic.impactOccurred()
            onTap(node.id)
        }
        .onTapGesture(count: 2) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            onOpen(node.id)
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            onLongPress(node.id)
        }
        .onAppear {
            haptic.prepare()
            if node.incomingLinks.count >= hubIncomingThreshold {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    hubPulse = 1.0
                }
            }
        }
    }

    private func triggerRipple() {
        rippleScale   = 0.8
        rippleOpacity = 0.8
        withAnimation(.easeOut(duration: 0.56)) {
            rippleScale   = 2.8
            rippleOpacity = 0.0
        }
    }
}

private struct StatusIndicatorView: View {
    let status: String
    let radius: CGFloat

    var body: some View {
        Group {
            if status == "planned" {
                Circle()
                    .stroke(statusColor(status).opacity(0.92), lineWidth: max(1.3, radius * 0.13))
                    .background(Circle().fill(Color.white.opacity(0.82)))
            } else {
                Circle()
                    .fill(statusColor(status))
                    .overlay(Circle().stroke(Color.white.opacity(0.86), lineWidth: max(1, radius * 0.08)))
            }
        }
        .frame(width: max(8, radius * 0.48), height: max(8, radius * 0.48))
        .shadow(color: statusColor(status).opacity(0.24), radius: 4, y: 1)
    }
}

func nodeTypeColor(_ type: String?) -> Color? {
    switch type?.lowercased() {
    case "project": return .vbPink
    case "concept": return .vbLavender
    case "person": return .warmPeach
    case "portfolio": return .blush
    case "reference": return .softGray
    case "experiment": return .vbMagenta
    case "goal": return .goldAccent
    default: return nil
    }
}

func statusColor(_ status: String?) -> Color {
    switch status?.lowercased() {
    case "wip": return .goldAccent
    case "done": return .vbSuccess
    case "archived": return .softGray
    case "evergreen": return .vbLavender
    case "planned": return .vbFg3
    default: return .vbFg4
    }
}

// MARK: – Long Press Menu

private struct LongPressMenuView: View {
    let node: GraphNode
    let connectedCount: Int
    let onOpen:         () -> Void
    let onCopyWikilink: () -> Void
    let onDismiss:      () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.vbFg1.opacity(0.22)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.vbLavender.opacity(0.40))
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)

                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.vbStardust, .vbMagenta, .vbLavender],
                                    center: UnitPoint(x: 0.35, y: 0.35),
                                    startRadius: 0, endRadius: 18
                                )
                            )
                            .frame(width: 36, height: 36)
                        Circle()
                            .fill(Color.white.opacity(0.60))
                            .frame(width: 9, height: 9)
                            .offset(x: -5, y: -5)
                            .blur(radius: 2)
                    }
                    .shadow(color: .vbMagenta.opacity(0.65), radius: 10)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(node.title)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.vbFg1)
                        Text("\(connectedCount) Synapsen")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.vbFg3)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 14)

                menuRow(icon: "arrow.up.right.square", label: "Notiz öffnen",    action: onOpen)
                menuRow(icon: "doc.on.doc",            label: "Wikilink kopieren", action: onCopyWikilink)
                menuRow(icon: "xmark",                 label: "Schließen",       action: onDismiss)
            }
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.white.opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.vbPink.opacity(0.18), lineWidth: 1)
                    )
            }
            .shadow(color: .vbPink.opacity(0.18), radius: 34, y: -8)
            .padding(.horizontal, 12)
            .padding(.bottom, 34)
        }
        .ignoresSafeArea()
    }

    private func menuRow(icon: String, label: String, danger: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(danger ? .vbDanger : .vbLavender)
                    .frame(width: 24, alignment: .center)
                Text(label)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(danger ? .vbDanger : .vbFg1)
                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .top) {
            Color.vbLavender.opacity(0.10).frame(height: 1)
        }
    }
}

// MARK: – Loading Universe

private struct LoadingUniverseView: View {
    let progress: Double

    private var headline: String {
        switch progress {
        case 0..<0.20:  return "Synaptic Vault startet…"
        case 0.20..<0.45: return "Lade deine Nodes…"
        case 0.45..<0.70: return "Ordne Synapsen…"
        case 0.70..<0.90: return "Zeichne dein Netz…"
        default:          return "Fast da…"
        }
    }

    private var subline: String {
        progress < 0.45 ? "Vault wird gelesen …" : "Synapsen werden verbunden…"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.vbVoid, .vbDeep, Color.white],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 44) {
                PearlView(size: 120)

                VStack(spacing: 28) {
                    Text(headline)
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                        .italic()
                        .foregroundColor(.vbFg2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                        .animation(.easeInOut(duration: 0.5), value: headline)

                    VStack(spacing: 10) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.vbDeep.opacity(0.88))
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [.vbPink, .vbLavender, .vbPeriwinkle],
                                            startPoint: .leading, endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(0, geo.size.width * progress))
                                    .shadow(color: .vbPink.opacity(0.60), radius: 6)
                            }
                        }
                        .frame(maxWidth: 280, maxHeight: 3)

                        HStack {
                            Text(subline)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.vbFg3)
                            Spacer()
                            Text("\(Int(progress * 100)) %")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.vbLavender)
                                .monospacedDigit()
                        }
                        .frame(maxWidth: 280)
                    }
                }
            }
        }
    }
}

// MARK: – Error Banner

private struct ErrorBannerView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.vbDanger)
                .font(.system(size: 13))
            Text(message)
                .font(.system(size: 12))
                .foregroundColor(.vbFg2)
                .lineLimit(2)
            Spacer()
            Button("Erneut", action: retry)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.vbLavender)
        }
        .padding(14)
        .background(Color(red: 0.086, green: 0.027, blue: 0.059))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.vbDanger.opacity(0.40), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}
