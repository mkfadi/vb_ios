// BrainView.swift – Interaktive 3D-Gehirn-Visualisierung mit SceneKit

import SwiftUI
import SceneKit

struct BrainView: View {
    @EnvironmentObject var viewModel: AppViewModel

    @State private var selectedNoteID: String?
    @State private var showNoteSheet  = false

    var body: some View {
        ZStack(alignment: .top) {

            Color.black.ignoresSafeArea()

            // SceneKit-Szene als Vollbild-Hintergrund
            BrainSceneView(
                nodes: viewModel.graphModel.nodes,
                edges: viewModel.graphModel.edges,
                onNodeTapped: { id in
                    selectedNoteID = id
                    showNoteSheet  = true
                }
            )
            .ignoresSafeArea()

            // Lade-Overlay
            if viewModel.graphModel.isLoading {
                LoadingOverlayView(progress: viewModel.graphModel.loadingProgress)
            }

            // Fehler-Banner
            if let err = viewModel.graphModel.errorMessage {
                ErrorBannerView(message: err) {
                    Task { await viewModel.loadNotes() }
                }
                .padding(.top, 60)
            }

            // Toolbar
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Virtual Brain")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                    Text("\(viewModel.graphModel.nodes.count) Notizen · \(viewModel.graphModel.edges.count) Links")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                Spacer()

                // Neu laden
                Button {
                    Task { await viewModel.loadNotes() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .disabled(viewModel.graphModel.isLoading)

                // Abmelden
                Button {
                    viewModel.logout()
                } label: {
                    Image(systemName: "person.slash")
                        .foregroundColor(.red.opacity(0.8))
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 56)
        }
        .sheet(isPresented: $showNoteSheet) {
            if let id = selectedNoteID {
                NoteView(noteID: id)
                    .environmentObject(viewModel)
            }
        }
        .task {
            if viewModel.graphModel.nodes.isEmpty {
                await viewModel.loadNotes()
            }
        }
    }
}

// MARK: – Lade-Overlay

private struct LoadingOverlayView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 22) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 52, weight: .ultraLight))
                    .foregroundStyle(LinearGradient(
                        colors: [.purple, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .symbolEffect(.pulse)
                Text("Lade Vault …")
                    .font(.headline)
                    .foregroundColor(.white)
                ProgressView(value: progress)
                    .tint(.purple)
                    .frame(width: 220)
                Text("\(Int(progress * 100)) %")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(36)
            .background(.ultraThinMaterial)
            .cornerRadius(24)
        }
    }
}

// MARK: – Fehler-Banner

private struct ErrorBannerView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(.caption)
                .foregroundColor(.white)
                .lineLimit(2)
            Spacer()
            Button("Erneut", action: retry)
                .font(.caption.bold())
                .foregroundColor(.purple)
        }
        .padding(14)
        .background(Color(red: 0.15, green: 0.05, blue: 0.05))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.4), lineWidth: 1))
        .padding(.horizontal, 16)
    }
}

// MARK: – SceneKit UIViewRepresentable

struct BrainSceneView: UIViewRepresentable {

    let nodes: [GraphNode]
    let edges: [GraphEdge]
    let onNodeTapped: (String) -> Void

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene            = context.coordinator.scene
        view.backgroundColor  = .black
        view.allowsCameraControl = true   // Pinch-Zoom + Drehen durch SceneKit
        view.autoenablesDefaultLighting  = false
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60

        let tap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleTap(_:))
        )
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // Szene nur neu aufbauen wenn sich die Knotenanzahl geändert hat
        guard context.coordinator.lastBuildCount != nodes.count else { return }
        context.coordinator.buildScene(nodes: nodes, edges: edges)
        context.coordinator.lastBuildCount = nodes.count
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onNodeTapped: onNodeTapped)
    }

    // MARK: Coordinator – verwaltet SCNScene und Tap-Handling

    final class Coordinator: NSObject {
        let scene = SCNScene()
        var onNodeTapped: (String) -> Void
        var nodeMap: [SCNNode: String] = [:]  // SCNNode → Note-ID
        var lastBuildCount = 0

        init(onNodeTapped: @escaping (String) -> Void) {
            self.onNodeTapped = onNodeTapped
            super.init()
            setupBaseScene()
        }

        // Richtet Kamera, Beleuchtung und äußere Gehirn-Kugel ein
        private func setupBaseScene() {
            // Kamera mit weitem Sichtfeld
            let cam      = SCNCamera()
            cam.zFar     = 300
            cam.fieldOfView = 60
            let camNode  = SCNNode()
            camNode.name = "camera"
            camNode.camera   = cam
            camNode.position = SCNVector3(0, 0, 22)
            scene.rootNode.addChildNode(camNode)

            // Weiches blaues Umgebungslicht
            let ambient      = SCNNode()
            ambient.light    = SCNLight()
            ambient.light!.type      = .ambient
            ambient.light!.color     = UIColor(red: 0.08, green: 0.05, blue: 0.25, alpha: 1)
            ambient.light!.intensity = 400
            scene.rootNode.addChildNode(ambient)

            // Violettes Hauptlicht von oben-vorne
            let key         = SCNNode()
            key.light       = SCNLight()
            key.light!.type      = .directional
            key.light!.color     = UIColor(red: 0.55, green: 0.25, blue: 1.0, alpha: 1)
            key.light!.intensity = 700
            key.position    = SCNVector3(8, 12, 10)
            scene.rootNode.addChildNode(key)

            // Blaues Fülllicht von hinten
            let fill        = SCNNode()
            fill.light      = SCNLight()
            fill.light!.type      = .directional
            fill.light!.color     = UIColor(red: 0.0, green: 0.3, blue: 0.8, alpha: 1)
            fill.light!.intensity = 300
            fill.position   = SCNVector3(-8, -5, -10)
            scene.rootNode.addChildNode(fill)

            // Transparente äußere Kugel – der "Gehirn-Container"
            let outerGeo  = SCNSphere(radius: 8.5)
            let outerMat  = SCNMaterial()
            outerMat.diffuse.contents   = UIColor(red: 0.4, green: 0.0, blue: 0.8, alpha: 0.04)
            outerMat.emission.contents  = UIColor(red: 0.2, green: 0.0, blue: 0.5, alpha: 0.08)
            outerMat.isDoubleSided      = true
            outerMat.transparency       = 0.88
            outerGeo.materials = [outerMat]
            let outerNode  = SCNNode(geometry: outerGeo)
            outerNode.name = "outerSphere"
            // Langsame Rotation für lebendigen Look
            outerNode.runAction(.repeatForever(.rotateBy(x: 0.02, y: 0.15, z: 0.01, duration: 10)))
            scene.rootNode.addChildNode(outerNode)
        }

        // Baut alle Node-Spheres und Kanten-Zylinder in die Szene ein
        func buildScene(nodes: [GraphNode], edges: [GraphEdge]) {
            // Alte Nodes und Edges entfernen (nicht Basis-Szene)
            scene.rootNode.childNodes
                .filter { $0.name?.hasPrefix("n_") == true || $0.name?.hasPrefix("e_") == true }
                .forEach { $0.removeFromParentNode() }
            nodeMap.removeAll()

            // Nodes
            for node in nodes {
                let scnNode = makeNodeSphere(node)
                scene.rootNode.addChildNode(scnNode)
                nodeMap[scnNode] = node.id
            }

            // Edges als dünne Zylinder
            let posMap = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0.position) })
            for (idx, edge) in edges.enumerated() {
                guard let from = posMap[edge.sourceID],
                      let to   = posMap[edge.targetID] else { continue }
                let edgeNode = makeEdgeCylinder(from: from, to: to, index: idx)
                scene.rootNode.addChildNode(edgeNode)
            }
        }

        // Erstellt eine Knotenspähere; Größe + Farbe hängen von Verbindungsanzahl ab
        private func makeNodeSphere(_ node: GraphNode) -> SCNNode {
            let connections = node.connectionCount
            let radius = CGFloat(0.10 + Float(connections) * 0.025).clamped(to: 0.10...0.55)

            let geo = SCNSphere(radius: radius)
            geo.segmentCount = 16

            // Farbverlauf: wenig verbunden = blau, viel verbunden = pink/magenta
            let t       = min(Double(connections) / 12.0, 1.0)
            let hue     = CGFloat(0.75 - t * 0.35)       // 0.75 = blau, 0.40 = magenta
            let sat     = CGFloat(0.7 + t * 0.3)
            let color   = UIColor(hue: hue, saturation: sat, brightness: 1.0, alpha: 1.0)

            let mat = SCNMaterial()
            mat.diffuse.contents  = color
            mat.emission.contents = color.withAlphaComponent(0.45)  // Glüheffekt
            mat.lightingModel     = .blinn
            mat.specular.contents = UIColor.white.withAlphaComponent(0.5)
            geo.materials = [mat]

            let scnNode = SCNNode(geometry: geo)
            scnNode.name = "n_\(node.id)"
            scnNode.position = node.position

            // Sanftes Pulsieren (zufälliger Versatz über sine für natürlicheren Look)
            let offset = Float.random(in: 0...Float.pi * 2)
            let pulse  = SCNAction.repeatForever(.customAction(duration: 2.5) { node, t in
                let s = Float(1.0 + 0.10 * sin(Double(t) * Double.pi * 2 + Double(offset)))
                node.scale = SCNVector3(s, s, s)
            })
            scnNode.runAction(pulse)

            return scnNode
        }

        // Erstellt einen Zylinder zwischen zwei 3D-Punkten (als Kante im Graphen)
        private func makeEdgeCylinder(from start: SCNVector3, to end: SCNVector3, index: Int) -> SCNNode {
            let dx = end.x - start.x
            let dy = end.y - start.y
            let dz = end.z - start.z
            let len = sqrt(dx*dx + dy*dy + dz*dz)
            guard len > 0.001 else { return SCNNode() }

            let geo = SCNCylinder(radius: 0.012, height: CGFloat(len))
            let mat = SCNMaterial()
            mat.diffuse.contents  = UIColor(red: 0.45, green: 0.20, blue: 0.90, alpha: 0.25)
            mat.emission.contents = UIColor(red: 0.25, green: 0.05, blue: 0.70, alpha: 0.15)
            mat.lightingModel     = .constant   // Kein Licht-Shading für Kanten
            geo.materials = [mat]

            let node = SCNNode(geometry: geo)
            node.name = "e_\(index)"

            // Zylinder in der Mitte zwischen Start und Endpunkt platzieren
            node.position = SCNVector3(
                (start.x + end.x) * 0.5,
                (start.y + end.y) * 0.5,
                (start.z + end.z) * 0.5
            )

            // Zylinder von Standard-Y-Achse auf Richtungsvektor drehen
            // Kreuzprodukt: Y × dir = Rotationsachse; dot = cos(Winkel)
            let nx = dx / len, ny = dy / len, nz = dz / len
            let dot = ny   // dot((0,1,0), (nx,ny,nz)) = ny

            if abs(dot + 1.0) < 0.001 {
                // Richtung ist genau −Y: 180° um X-Achse drehen
                node.eulerAngles = SCNVector3(Float.pi, 0, 0)
            } else if abs(dot - 1.0) > 0.001 {
                // Kreuzprodukt: (0,1,0) × (nx,ny,nz) = (nz, 0, −nx)
                let cx = nz, cy: Float = 0, cz = -nx
                let cLen = sqrt(cx*cx + cz*cz)
                if cLen > 0.001 {
                    node.rotation = SCNVector4(cx / cLen, cy, cz / cLen, acos(max(-1, min(1, dot))))
                }
            }

            return node
        }

        // Verarbeitet Tap-Gesten auf der SCNView und findet den angetippten Node
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let scnView = gesture.view as? SCNView else { return }
            let pt   = gesture.location(in: scnView)
            let hits = scnView.hitTest(pt, options: [
                SCNHitTestOption.boundingBoxOnly: false,
                SCNHitTestOption.firstFoundOnly:  true
            ])

            for hit in hits {
                // Gehe Node-Hierarchie hoch (falls zusammengesetzte Geometrie)
                var node: SCNNode? = hit.node
                while let n = node {
                    if let noteID = nodeMap[n] {
                        // Visuelles Flash-Feedback beim Antippen
                        let flash = SCNAction.sequence([
                            .scale(to: 2.2, duration: 0.08),
                            .scale(to: 1.0, duration: 0.18)
                        ])
                        n.runAction(flash)
                        // State-Update muss auf Main-Thread
                        DispatchQueue.main.async { self.onNodeTapped(noteID) }
                        return
                    }
                    node = n.parent
                }
            }
        }
    }
}

// Hilfserweiterung: Begrenzt einen Comparable-Wert auf ein Intervall
private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
