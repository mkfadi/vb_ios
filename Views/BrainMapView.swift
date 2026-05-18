// Views/BrainMapView.swift – Anatomische Brain-Map mit 7 Modulen

import SwiftUI

// MARK: – Module Data

private struct BrainModule: Identifiable {
    let id: String          // vault folder name
    let label: String       // display name (caps)
    let subLabel: String    // brain region name
    let icon: String        // SF Symbol
    let regionColor: Color
    let accentColor: Color
    // Region position within brain frame (0–1)
    let regionCenter: CGPoint
    let regionScale: CGSize
    // Chip center offset from brain-center (points)
    let chipOffset: CGPoint
    // Connector anchor on brain surface (0–1 of brain frame)
    let connectorAnchor: CGPoint
}

private let brainModules: [BrainModule] = [
    BrainModule(
        id: "pfc-ceo",
        label: "ORGANISED",
        subLabel: "PFC",
        icon: "folder.fill",
        regionColor: Color(red: 0.99, green: 0.88, blue: 0.48).opacity(0.75),
        accentColor: Color(red: 0.80, green: 0.62, blue: 0.10),
        regionCenter: CGPoint(x: 0.24, y: 0.36),
        regionScale: CGSize(width: 0.42, height: 0.52),
        chipOffset: CGPoint(x: -122, y: -72),
        connectorAnchor: CGPoint(x: 0.16, y: 0.36)
    ),
    BrainModule(
        id: "default-mode-network",
        label: "IDENTITY",
        subLabel: "DEFAULT MODE",
        icon: "cloud.fill",
        regionColor: Color(red: 0.80, green: 0.76, blue: 0.97).opacity(0.75),
        accentColor: Color(red: 0.62, green: 0.52, blue: 0.94),
        regionCenter: CGPoint(x: 0.50, y: 0.20),
        regionScale: CGSize(width: 0.44, height: 0.36),
        chipOffset: CGPoint(x: 5, y: -148),
        connectorAnchor: CGPoint(x: 0.50, y: 0.08)
    ),
    BrainModule(
        id: "hippocampus-erinnerungen",
        label: "MEMORY",
        subLabel: "HIPPOCAMPUS",
        icon: "book.closed.fill",
        regionColor: Color(red: 0.62, green: 0.81, blue: 0.97).opacity(0.75),
        accentColor: Color(red: 0.35, green: 0.60, blue: 0.90),
        regionCenter: CGPoint(x: 0.74, y: 0.30),
        regionScale: CGSize(width: 0.36, height: 0.44),
        chipOffset: CGPoint(x: 128, y: -72),
        connectorAnchor: CGPoint(x: 0.82, y: 0.20)
    ),
    BrainModule(
        id: "amygdala-k2g",
        label: "EMOTION",
        subLabel: "AMYGDALA",
        icon: "heart.fill",
        regionColor: Color(red: 0.98, green: 0.72, blue: 0.76).opacity(0.75),
        accentColor: Color(red: 0.90, green: 0.38, blue: 0.48),
        regionCenter: CGPoint(x: 0.21, y: 0.62),
        regionScale: CGSize(width: 0.30, height: 0.36),
        chipOffset: CGPoint(x: -128, y: 38),
        connectorAnchor: CGPoint(x: 0.12, y: 0.58)
    ),
    BrainModule(
        id: "kortex-market",
        label: "HABITS",
        subLabel: "KORTEX",
        icon: "arrow.2.circlepath",
        regionColor: Color(red: 0.62, green: 0.92, blue: 0.86).opacity(0.75),
        accentColor: Color(red: 0.24, green: 0.72, blue: 0.66),
        regionCenter: CGPoint(x: 0.75, y: 0.56),
        regionScale: CGSize(width: 0.34, height: 0.38),
        chipOffset: CGPoint(x: 128, y: 55),
        connectorAnchor: CGPoint(x: 0.86, y: 0.52)
    ),
    BrainModule(
        id: "nucleus-accumbens-dopamin",
        label: "MOTIVATION",
        subLabel: "DOPAMINE",
        icon: "bolt.fill",
        regionColor: Color(red: 0.52, green: 0.92, blue: 0.80).opacity(0.75),
        accentColor: Color(red: 0.18, green: 0.74, blue: 0.64),
        regionCenter: CGPoint(x: 0.65, y: 0.78),
        regionScale: CGSize(width: 0.32, height: 0.28),
        chipOffset: CGPoint(x: 122, y: 148),
        connectorAnchor: CGPoint(x: 0.77, y: 0.84)
    ),
    BrainModule(
        id: "hypothalamus-life-support",
        label: "REGULATE",
        subLabel: "HYPOTHALAMUS",
        icon: "leaf.fill",
        regionColor: Color(red: 0.72, green: 0.95, blue: 0.72).opacity(0.75),
        accentColor: Color(red: 0.30, green: 0.74, blue: 0.38),
        regionCenter: CGPoint(x: 0.38, y: 0.84),
        regionScale: CGSize(width: 0.30, height: 0.24),
        chipOffset: CGPoint(x: -18, y: 158),
        connectorAnchor: CGPoint(x: 0.33, y: 0.90)
    ),
]

// MARK: – Main View

struct BrainMapView: View {
    @EnvironmentObject var viewModel: AppViewModel
    @State private var selectedModuleID: String?
    @State private var showModuleSheet = false

    private let brainW: CGFloat = 288
    private let brainH: CGFloat = 198

    var body: some View {
        GeometryReader { geo in
            let cx = geo.size.width / 2
            let cy = geo.size.height * 0.455
            let originX = cx - brainW / 2
            let originY = cy - brainH / 2

            ZStack {
                // Connector lines (drawn behind everything)
                Canvas { ctx, _ in
                    for module in brainModules {
                        let anchor = CGPoint(
                            x: originX + module.connectorAnchor.x * brainW,
                            y: originY + module.connectorAnchor.y * brainH
                        )
                        let chipCenter = CGPoint(
                            x: cx + module.chipOffset.x,
                            y: cy + module.chipOffset.y
                        )
                        let isSelected = module.id == selectedModuleID
                        var path = Path()
                        path.move(to: chipCenter)
                        path.addLine(to: anchor)
                        ctx.stroke(
                            path,
                            with: .color(module.accentColor.opacity(isSelected ? 0.70 : 0.35)),
                            style: StrokeStyle(lineWidth: isSelected ? 1.4 : 0.9, dash: [5, 4])
                        )
                    }
                }
                .allowsHitTesting(false)

                // Brain illustration
                BrainIllustration(selectedModuleID: selectedModuleID)
                    .frame(width: brainW, height: brainH)
                    .position(x: cx, y: cy)

                // Module chips
                ForEach(brainModules) { module in
                    ModuleChipView(module: module, isSelected: selectedModuleID == module.id)
                        .position(x: cx + module.chipOffset.x, y: cy + module.chipOffset.y)
                        .onTapGesture {
                            withAnimation(.spring(duration: 0.28)) {
                                selectedModuleID = module.id
                            }
                            showModuleSheet = true
                        }
                }
            }
        }
        .sheet(isPresented: $showModuleSheet, onDismiss: {
            withAnimation { selectedModuleID = nil }
        }) {
            if let id = selectedModuleID,
               let mod = brainModules.first(where: { $0.id == id }) {
                ModuleNotesSheet(module: mod)
                    .environmentObject(viewModel)
            }
        }
    }
}

// MARK: – Brain Illustration

private struct BrainIllustration: View {
    let selectedModuleID: String?

    var body: some View {
        ZStack {
            // Cerebellum (behind cerebrum)
            Ellipse()
                .fill(Color(red: 0.93, green: 0.90, blue: 0.86))
                .frame(width: 88, height: 56)
                .offset(x: 70, y: 56)

            Ellipse()
                .stroke(Color(red: 0.84, green: 0.80, blue: 0.74).opacity(0.5), lineWidth: 1)
                .frame(width: 88, height: 56)
                .offset(x: 70, y: 56)

            // Brain stem
            Capsule()
                .fill(Color(red: 0.90, green: 0.87, blue: 0.83))
                .frame(width: 20, height: 34)
                .offset(x: 6, y: 86)

            // Main cerebrum base fill
            CerebrumShape()
                .fill(Color(red: 0.97, green: 0.94, blue: 0.89))

            // Colored regions (clipped to cerebrum)
            ZStack {
                ForEach(brainModules) { module in
                    GeometryReader { geo in
                        Ellipse()
                            .fill(module.regionColor)
                            .frame(
                                width: module.regionScale.width  * geo.size.width,
                                height: module.regionScale.height * geo.size.height
                            )
                            .position(
                                x: module.regionCenter.x * geo.size.width,
                                y: module.regionCenter.y * geo.size.height
                            )
                            .opacity(selectedModuleID == nil || selectedModuleID == module.id ? 1 : 0.22)
                            .animation(.easeInOut(duration: 0.25), value: selectedModuleID)
                    }
                }
            }
            .clipShape(CerebrumShape())

            // Major sulci lines
            SulciView()
                .clipShape(CerebrumShape())

            // Cerebrum outline
            CerebrumShape()
                .stroke(Color(red: 0.84, green: 0.80, blue: 0.74).opacity(0.65), lineWidth: 1.5)
        }
    }
}

// MARK: – Sulci (drawn as Shape to avoid tuple issues in Canvas)

private struct SulciView: View {
    private struct Sulcus {
        let sx, sy, ex, ey, c1x, c1y, c2x, c2y: CGFloat
    }
    private let sulci: [Sulcus] = [
        Sulcus(sx: 0.36, sy: 0.08, ex: 0.40, ey: 0.70, c1x: 0.34, c1y: 0.28, c2x: 0.38, c2y: 0.50),
        Sulcus(sx: 0.10, sy: 0.55, ex: 0.66, ey: 0.50, c1x: 0.28, c1y: 0.58, c2x: 0.50, c2y: 0.50),
        Sulcus(sx: 0.18, sy: 0.10, ex: 0.20, ey: 0.50, c1x: 0.16, c1y: 0.28, c2x: 0.19, c2y: 0.40),
    ]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            Canvas { ctx, _ in
                for s in sulci {
                    var path = Path()
                    path.move(to: CGPoint(x: s.sx * w, y: s.sy * h))
                    path.addCurve(
                        to: CGPoint(x: s.ex * w, y: s.ey * h),
                        control1: CGPoint(x: s.c1x * w, y: s.c1y * h),
                        control2: CGPoint(x: s.c2x * w, y: s.c2y * h)
                    )
                    ctx.stroke(path, with: .color(Color(red: 0.78, green: 0.72, blue: 0.66).opacity(0.40)), lineWidth: 1.0)
                }
            }
        }
    }
}

// MARK: – Cerebrum Shape (lateral view)

private struct CerebrumShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        let ox = rect.minX
        let oy = rect.minY

        func pt(_ fx: CGFloat, _ fy: CGFloat) -> CGPoint {
            CGPoint(x: ox + fx * w, y: oy + fy * h)
        }

        var p = Path()
        // Bottom-front
        p.move(to: pt(0.13, 0.84))
        // Frontal lobe (front arc)
        p.addCurve(to: pt(0.03, 0.44),
                   control1: pt(0.02, 0.74), control2: pt(0.01, 0.60))
        // Frontal pole to top-front
        p.addCurve(to: pt(0.22, 0.06),
                   control1: pt(0.03, 0.28), control2: pt(0.08, 0.08))
        // Parietal top
        p.addCurve(to: pt(0.54, 0.03),
                   control1: pt(0.34, 0.01), control2: pt(0.44, 0.01))
        // Occipital top
        p.addCurve(to: pt(0.80, 0.10),
                   control1: pt(0.65, 0.02), control2: pt(0.74, 0.04))
        // Occipital pole
        p.addCurve(to: pt(0.95, 0.38),
                   control1: pt(0.94, 0.14), control2: pt(0.99, 0.26))
        // Temporal back
        p.addCurve(to: pt(0.88, 0.64),
                   control1: pt(0.97, 0.50), control2: pt(0.96, 0.58))
        // Temporal notch (cerebellum boundary)
        p.addCurve(to: pt(0.63, 0.76),
                   control1: pt(0.82, 0.72), control2: pt(0.74, 0.76))
        // Bottom temporal toward front
        p.addCurve(to: pt(0.13, 0.84),
                   control1: pt(0.46, 0.80), control2: pt(0.28, 0.88))
        p.closeSubpath()
        return p
    }
}

// MARK: – Module Chip

private struct ModuleChipView: View {
    let module: BrainModule
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: module.icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(module.accentColor)

            VStack(alignment: .leading, spacing: 1) {
                Text(module.label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color(red: 0.15, green: 0.10, blue: 0.25))
                    .tracking(0.4)
                Text(module.subLabel)
                    .font(.system(size: 8.5, weight: .medium))
                    .foregroundColor(Color(red: 0.45, green: 0.40, blue: 0.55))
                    .tracking(0.2)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isSelected ? Color.white : Color.white.opacity(0.92))
                .shadow(color: module.accentColor.opacity(isSelected ? 0.40 : 0.12),
                        radius: isSelected ? 10 : 4, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(module.accentColor.opacity(isSelected ? 0.65 : 0.28),
                        lineWidth: isSelected ? 1.5 : 1.0)
        )
        .scaleEffect(isSelected ? 1.07 : 1.0)
        .animation(.spring(duration: 0.28), value: isSelected)
    }
}

// MARK: – Module Notes Sheet

private struct ModuleNotesSheet: View {
    let module: BrainModule
    @EnvironmentObject var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedNoteID: String?
    @State private var showNoteSheet = false

    private var notes: [Note] {
        viewModel.notes.values
            .filter { $0.path.hasPrefix(module.id + "/") }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.vbDeep.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        moduleHeader
                        if notes.isEmpty {
                            emptyState
                        } else {
                            LazyVStack(spacing: 8) {
                                ForEach(notes) { note in
                                    noteRow(note)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 36)
                        }
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Schließen") { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.vbLavender)
                }
            }
            .toolbarBackground(Color.vbDeep, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .presentationCornerRadius(28)
        .presentationBackground(Color.vbDeep)
        .sheet(isPresented: $showNoteSheet) {
            if let id = selectedNoteID {
                NoteView(noteID: id).environmentObject(viewModel)
            }
        }
    }

    private var moduleHeader: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(module.regionColor)
                    .frame(width: 46, height: 46)
                Image(systemName: module.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(module.accentColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(module.label)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.vbFg1)
                Text(module.subLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.vbFg3)
                    .tracking(0.8)
                    .textCase(.uppercase)
            }
            Spacer()
            Text("\(notes.count)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(module.accentColor)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 20)
    }

    private func noteRow(_ note: Note) -> some View {
        Button {
            selectedNoteID = note.id
            showNoteSheet = true
        } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(module.regionColor)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 3) {
                    Text(note.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.vbFg1)
                    if let type = note.frontmatter?.type {
                        Text(type)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.vbFg3)
                            .tracking(0.4)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.vbFg4)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(module.accentColor.opacity(0.14), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: module.icon)
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(module.accentColor.opacity(0.5))
            Text("Noch keine Notizen")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.vbFg3)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
