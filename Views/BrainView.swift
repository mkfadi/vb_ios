//
//  BrainView.swift
//  vb_ios

import SwiftUI
import SceneKit   // SCNVector3.x / .y

// MARK: – Design Tokens (module-wide)

extension Color {
    static let vbVoid       = Color(red: 0.024, green: 0.012, blue: 0.098)  // #06031a
    static let vbDeep       = Color(red: 0.047, green: 0.031, blue: 0.141)  // #0c0824
    static let vbNebula     = Color(red: 0.086, green: 0.043, blue: 0.188)  // #160b30
    static let vbRose       = Color(red: 1.000, green: 0.561, blue: 0.702)  // #ff8fb3
    static let vbPink       = Color(red: 1.000, green: 0.435, blue: 0.639)  // #ff6fa3
    static let vbMagenta    = Color(red: 1.000, green: 0.353, blue: 0.627)  // #ff5aa0
    static let vbLavender   = Color(red: 0.788, green: 0.643, blue: 1.000)  // #c9a4ff
    static let vbLilac      = Color(red: 0.710, green: 0.553, blue: 1.000)  // #b58dff
    static let vbOrchid     = Color(red: 0.847, green: 0.537, blue: 1.000)  // #d889ff
    static let vbPeriwinkle = Color(red: 0.639, green: 0.659, blue: 1.000)  // #a3a8ff
    static let vbStardust   = Color(red: 1.000, green: 0.941, blue: 0.969)  // #fff0f7
    static let vbFg1        = Color(red: 0.984, green: 0.953, blue: 1.000)  // #fbf3ff
    static let vbFg2        = Color(red: 0.831, green: 0.761, blue: 0.925)  // #d4c2ec
    static let vbFg3        = Color(red: 0.592, green: 0.518, blue: 0.722)  // #9784b8
    static let vbFg4        = Color(red: 0.420, green: 0.353, blue: 0.529)  // #6b5a87
    static let vbSuccess    = Color(red: 0.533, green: 0.902, blue: 0.765)  // #88e6c3
    static let vbDanger     = Color(red: 1.000, green: 0.478, blue: 0.541)  // #ff7a8a
}

// MARK: – Pearl (brand mark, shared across screens)

struct PearlView: View {
    let size: CGFloat
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.vbPink.opacity(0.55), Color.vbLavender.opacity(0.25), .clear],
                        center: .center, startRadius: 0, endRadius: size * 0.62
                    )
                )
                .frame(width: size * 1.3, height: size * 1.3)
                .blur(radius: size * 0.15)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            .vbStardust,
                            Color(red: 1, green: 0.769, blue: 0.863),
                            .vbRose,
                            .vbLavender,
                            Color(red: 0.353, green: 0.176, blue: 0.639)
                        ],
                        center: UnitPoint(x: 0.35, y: 0.32),
                        startRadius: 0, endRadius: size * 0.5
                    )
                )
                .frame(width: size, height: size)
                .scaleEffect(pulse ? 1.04 : 1.0)
                .shadow(color: .vbPink.opacity(0.45), radius: size * 0.2)

            Ellipse()
                .fill(Color.white.opacity(0.65))
                .frame(width: size * 0.26, height: size * 0.30)
                .offset(x: -size * 0.12, y: -size * 0.14)
                .blur(radius: size * 0.04)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.6).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

// MARK: – Cosmic Background

private struct CosmicBackgroundView: View {
    var body: some View {
        ZStack {
            Color.vbVoid
            RadialGradient(
                colors: [Color.vbLavender.opacity(0.18), .clear],
                center: UnitPoint(x: 0.30, y: 0.20),
                startRadius: 0, endRadius: 300
            )
            RadialGradient(
                colors: [Color.vbPink.opacity(0.14), .clear],
                center: UnitPoint(x: 0.75, y: 0.80),
                startRadius: 0, endRadius: 280
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
            return (x, y, r, Double(i) * 0.37)
        }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.08)) { tl in
            let t = tl.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                for (nx, ny, r, phase) in Self.stars {
                    let alpha = 0.08 + 0.22 * (0.5 + 0.5 * sin(t * 0.65 + phase))
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: nx * size.width  - r,
                            y: ny * size.height - r,
                            width: r * 2, height: r * 2
                        )),
                        with: .color(.white.opacity(alpha))
                    )
                }
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
                    onNodeTapped: { id in
                        selectedNoteID = id
                        showNoteSheet  = true
                    },
                    onNodeLongPressed: { id in
                        longPressNodeID = id
                        selectedNoteID  = id
                        withAnimation(.spring(duration: 0.35)) { showLongPress = true }
                    }
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
                onRefresh: { Task { await viewModel.loadNotes() } },
                onLogout:  { viewModel.logout() }
            )
            .zIndex(20)
        }
        .overlay {
            if showLongPress,
               let nodeID = longPressNodeID,
               let node   = viewModel.graphModel.nodes.first(where: { $0.id == nodeID }) {
                let degree = viewModel.graphModel.edges.filter {
                    $0.sourceID == nodeID || $0.targetID == nodeID
                }.count
                LongPressMenuView(
                    node: node,
                    connectedCount: degree,
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
        .task {
            if viewModel.graphModel.nodes.isEmpty {
                await viewModel.loadNotes()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            PearlView(size: 72)
            Text("Tippe ↺ um den Vault zu laden")
                .font(.system(size: 16, design: .serif))
                .italic()
                .foregroundColor(.vbFg3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: – Toolbar Pill

private struct ToolbarPillView: View {
    let noteCount: Int
    let linkCount: Int
    let isLoading: Bool
    let onRefresh: () -> Void
    let onLogout:  () -> Void

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Virtual Brain")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundColor(.vbFg1)
                Text("\(noteCount) Notizen · \(linkCount) Links")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.vbFg3)
                    .monospacedDigit()
            }
            Spacer()
            pillButton(icon: "arrow.clockwise", danger: false, action: onRefresh)
                .disabled(isLoading)
            pillButton(icon: "person.slash", danger: true, action: onLogout)
        }
        .padding(.vertical, 9)
        .padding(.leading, 18)
        .padding(.trailing, 10)
        .background {
            Capsule()
                .fill(Color(red: 0.078, green: 0.031, blue: 0.157).opacity(0.62))
                .overlay(Capsule().stroke(Color.vbLavender.opacity(0.18), lineWidth: 1))
                .shadow(color: .black.opacity(0.40), radius: 12, y: 4)
        }
        .padding(.horizontal, 16)
        .padding(.top, 60)
    }

    private func pillButton(icon: String, danger: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(danger ? .vbDanger : .vbFg2)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.07))
                        .overlay(Circle().stroke(Color.vbLavender.opacity(0.15), lineWidth: 1))
                )
        }
    }
}

// MARK: – 3D Graph

struct BrainGraphView: View {
    let nodes: [GraphNode]
    let edges: [GraphEdge]
    let selectedNodeID: String?
    let onNodeTapped:      (String) -> Void
    let onNodeLongPressed: (String) -> Void

    @State private var zoom: CGFloat = 1.0
    @GestureState private var pinchDelta: CGFloat = 1.0
    // User-controlled rotation (drag to spin)
    @State private var userRotY: Double = 0
    @State private var userRotX: Double = 0
    @GestureState private var dragDelta: CGSize = .zero

    private var sz: CGSize { UIScreen.main.bounds.size }

    private var connectedIDs: Set<String> {
        guard let sel = selectedNodeID else { return [] }
        var ids = Set<String>()
        for e in edges {
            if e.sourceID == sel { ids.insert(e.targetID) }
            if e.targetID == sel { ids.insert(e.sourceID) }
        }
        return ids
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { tl in
            let t     = tl.date.timeIntervalSinceReferenceDate
            // Auto-drift + user input on both axes
            let rotY  = t * 0.032 + userRotY + dragDelta.width  * 0.004
            let rotX  = 0.22 + 0.06 * sin(t * 0.09)           // gentle tilt oscillation
                      + userRotX + dragDelta.height * 0.003
            let clampX = max(-0.55, min(0.55, rotX))

            let projected = computeProjections(rotY: rotY, rotX: clampX, size: sz)
            let idToPos   = Dictionary(uniqueKeysWithValues: projected.map { ($0.id, $0) })
            let connected = connectedIDs
            let selID     = selectedNodeID

            ZStack {
                // Edges + labels
                Canvas { ctx, _ in
                    for edge in edges {
                        guard let a = idToPos[edge.sourceID],
                              let b = idToPos[edge.targetID] else { continue }
                        let isLit = selID.map { edge.sourceID == $0 || edge.targetID == $0 } ?? false
                        let baseAlpha: Double = selID == nil ? 0.22 : (isLit ? 0.70 : 0.04)
                        let depthFade = Double((a.depthScale + b.depthScale) / 2.0)
                        let edgeColor = isLit ? Color.vbLavender : Color.vbPink
                        var path = Path()
                        path.move(to: a.screenPos)
                        path.addLine(to: b.screenPos)
                        ctx.stroke(path,
                                   with: .color(edgeColor.opacity(baseAlpha * depthFade)),
                                   lineWidth: isLit ? 1.5 : 0.8)
                    }
                    // Labels only for close/selected nodes
                    for item in projected where !item.isDimmed(selID: selID, connected: connected) {
                        guard item.depthScale > 0.78 else { continue }
                        let r = baseRadius(item.node) * item.depthScale
                        let label = ctx.resolve(
                            Text(String(item.node.title.prefix(13)))
                                .font(.system(size: max(7, 9 * item.depthScale), weight: .medium))
                        )
                        ctx.draw(label,
                                 at: CGPoint(x: item.screenPos.x, y: item.screenPos.y + r + 6),
                                 anchor: .top)
                    }
                }
                .foregroundStyle(Color.vbFg2.opacity(0.70))
                .allowsHitTesting(false)

                // Nodes rendered back-to-front (painter's algorithm)
                ForEach(projected.sorted { $0.z < $1.z }) { item in
                    let isSelected = item.id == selID
                    let isNeighbor = connected.contains(item.id)
                    let isDim      = selID != nil && !isSelected && !isNeighbor
                    GirlyNodeView(
                        node: item.node,
                        isSelected: isSelected,
                        isNeighbor: isNeighbor,
                        isDim: isDim,
                        depthScale: item.depthScale,
                        onTap: onNodeTapped,
                        onLongPress: onNodeLongPressed
                    )
                    .opacity(item.depthOpacity)
                    .position(item.screenPos)
                }
            }
        }
        .frame(width: sz.width, height: sz.height)
        .scaleEffect(zoom * pinchDelta, anchor: .center)
        .gesture(
            MagnificationGesture()
                .updating($pinchDelta) { v, s, _ in s = v }
                .onEnded { v in zoom = max(0.25, min(5.0, zoom * v)) }
                .simultaneously(with:
                    DragGesture(minimumDistance: 5)
                        .updating($dragDelta) { v, s, _ in s = v.translation }
                        .onEnded { v in
                            userRotY += v.translation.width  * 0.004
                            userRotX  = max(-0.55, min(0.55,
                                userRotX + v.translation.height * 0.003))
                        }
                )
        )
    }

    // MARK: Projected node data

    private struct ProjectedNode: Identifiable {
        let id: String
        let node: GraphNode
        let screenPos: CGPoint
        let depthScale: CGFloat
        let depthOpacity: Double
        let z: Float

        func isDimmed(selID: String?, connected: Set<String>) -> Bool {
            guard let s = selID else { return false }
            return id != s && !connected.contains(id)
        }
    }

    private func computeProjections(rotY: Double, rotX: Double, size: CGSize) -> [ProjectedNode] {
        nodes.map { node in
            let p = rotate3D(node.position, rotY: rotY, rotX: rotX)
            let (pos, dScale) = perspectiveProject(p, size: size)
            // Opacity: close nodes fully visible, far nodes slightly faded
            let depthOpacity = Double(max(0.45, min(1.0, 0.60 + 0.40 * (1.0 - (Double(p.z) + 5.5) / 11.0))))
            return ProjectedNode(id: node.id, node: node, screenPos: pos,
                                 depthScale: dScale, depthOpacity: depthOpacity, z: p.z)
        }
    }

    // Rotate SCNVector3 around Y then X axis
    private func rotate3D(_ pos: SCNVector3, rotY: Double, rotX: Double) -> SIMD3<Float> {
        let cosY = Float(cos(rotY)), sinY = Float(sin(rotY))
        let x1   = pos.x * cosY + pos.z * sinY
        let z1   = -pos.x * sinY + pos.z * cosY

        let cosX = Float(cos(rotX)), sinX = Float(sin(rotX))
        let y2   = pos.y * cosX - z1 * sinX
        let z2   = pos.y * sinX + z1 * cosX

        return SIMD3<Float>(x1, y2, z2)
    }

    // Perspective projection: closer nodes appear larger and positioned with parallax
    private func perspectiveProject(_ p: SIMD3<Float>, size: CGSize) -> (CGPoint, CGFloat) {
        let base: CGFloat = min(size.width, size.height) / 14.0
        let cam:  Float   = 22.0              // virtual camera distance
        let dz            = cam + p.z         // depth (always positive with cam=22, z in [-5,5])
        let f             = CGFloat(cam / max(dz, 0.5))   // perspective factor
        let x = size.width  / 2 + CGFloat(p.x) * base * f
        let y = size.height / 2 - CGFloat(p.y) * base * f
        // depthScale drives node size: close = ~1.27×, far = ~0.81×
        return (CGPoint(x: x, y: y), max(0.5, min(1.5, f)))
    }

    private func baseRadius(_ node: GraphNode) -> CGFloat {
        CGFloat(max(10, min(24, 10 + Double(node.connectionCount) * 1.8)))
    }
}

// MARK: – Node Dot

private struct GirlyNodeView: View {
    let node: GraphNode
    let isSelected: Bool
    let isNeighbor: Bool
    let isDim: Bool
    let depthScale: CGFloat   // perspective size modifier (0.5 – 1.5)
    let onTap:       (String) -> Void
    let onLongPress: (String) -> Void

    @State private var pulse = false
    @State private var rippleScale:   CGFloat = 0.8
    @State private var rippleOpacity: Double  = 0.0

    private let haptic = UIImpactFeedbackGenerator(style: .medium)

    private var baseR: CGFloat {
        CGFloat(max(10, min(24, 10 + Double(node.connectionCount) * 1.8))) * depthScale
    }
    private var r: CGFloat { isSelected ? baseR * 1.5 : baseR }

    private var pearlColors: [Color] {
        if isSelected {
            return [.vbStardust, Color(red: 1, green: 0.75, blue: 0.86), .vbMagenta, .vbLavender,
                    Color(red: 0.353, green: 0.176, blue: 0.639)]
        }
        let t = Double(min(node.connectionCount, 12)) / 12.0
        if t > 0.6 {
            return [.vbStardust, .vbRose, .vbOrchid, Color(red: 0.588, green: 0.318, blue: 0.902),
                    Color(red: 0.353, green: 0.176, blue: 0.639)]
        }
        return [.vbStardust, .vbRose, .vbPink, .vbLavender,
                Color(red: 0.353, green: 0.176, blue: 0.639)]
    }

    private var glowColor: Color {
        isSelected ? .vbMagenta : (isNeighbor ? .vbLavender : .vbPink)
    }

    var body: some View {
        ZStack {
            // Outer aura
            Circle()
                .fill(glowColor.opacity(pulse ? 0.22 : 0.06))
                .frame(width: r * 3.4, height: r * 3.4)
                .blur(radius: 10)
                .animation(.easeInOut(duration: 0.3), value: isSelected)

            // Ripple
            Circle()
                .stroke(Color.vbLavender.opacity(rippleOpacity), lineWidth: 1.5)
                .frame(width: r * rippleScale * 2, height: r * rippleScale * 2)

            // Inner halo
            Circle()
                .fill(glowColor.opacity(pulse ? 0.30 : 0.10))
                .frame(width: r * 2.5, height: r * 2.5)
                .blur(radius: 8)
                .animation(.easeInOut(duration: 0.3), value: isSelected)

            // Pearl body
            Circle()
                .fill(
                    RadialGradient(
                        colors: pearlColors,
                        center: UnitPoint(x: 0.35, y: 0.32),
                        startRadius: 0, endRadius: r
                    )
                )
                .frame(width: r * 2, height: r * 2)

            // Specular
            Circle()
                .fill(Color.white.opacity(0.65))
                .frame(width: r * 0.45, height: r * 0.45)
                .offset(x: -r * 0.22, y: -r * 0.22)
                .blur(radius: r * 0.12)
        }
        .opacity(isDim ? 0.18 : 1.0)
        .animation(.easeInOut(duration: 0.28), value: isDim)
        .animation(.easeInOut(duration: 0.28), value: isSelected)
        .contentShape(Circle().size(CGSize(width: r * 3.4, height: r * 3.4)))
        .onTapGesture {
            triggerRipple()
            haptic.impactOccurred()
            onTap(node.id)
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
            onLongPress(node.id)
        }
        .onAppear {
            withAnimation(
                .easeInOut(duration: Double.random(in: 1.8...3.2))
                .repeatForever(autoreverses: true)
                .delay(Double.random(in: 0...2.0))
            ) { pulse = true }
            haptic.prepare()
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

// MARK: – Long Press Menu

private struct LongPressMenuView: View {
    let node: GraphNode
    let connectedCount: Int
    let onOpen:         () -> Void
    let onCopyWikilink: () -> Void
    let onDismiss:      () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.52)
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
                            .font(.system(size: 22, weight: .medium, design: .serif))
                            .foregroundColor(.vbFg1)
                        Text("\(connectedCount) verbundene Notizen")
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
                    .fill(Color(red: 0.071, green: 0.031, blue: 0.149).opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(Color.vbLavender.opacity(0.18), lineWidth: 1)
                    )
            }
            .shadow(color: .black.opacity(0.70), radius: 40, y: -8)
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
        case 0..<0.20:  return "Dein Gedankenuniversum erwacht…"
        case 0.20..<0.45: return "Sammle deine Sterne…"
        case 0.45..<0.70: return "Verknüpfe deine Gedanken…"
        case 0.70..<0.90: return "Baue dein Universum…"
        default:          return "Fast da…"
        }
    }

    private var subline: String {
        progress < 0.45 ? "Lade Vault …" : "Verbinde Notizen…"
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.165, green: 0.082, blue: 0.314), .vbDeep, .vbVoid],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 44) {
                PearlView(size: 120)

                VStack(spacing: 28) {
                    Text(headline)
                        .font(.system(size: 22, design: .serif))
                        .italic()
                        .foregroundColor(.vbFg2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 280)
                        .animation(.easeInOut(duration: 0.5), value: headline)

                    VStack(spacing: 10) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.white.opacity(0.08))
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
