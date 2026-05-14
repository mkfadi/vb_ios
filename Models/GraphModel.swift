// GraphModel.swift – Graphstruktur: Nodes (Notizen) und Edges (Wikilinks)

import Foundation
import SceneKit
import simd

// Ein Knoten im Graphen – entspricht einer einzelnen Notiz
struct GraphNode: Identifiable, Sendable {
    let id: String           // Note-Pfad
    let title: String        // Anzeigename
    var position: SCNVector3 // Berechnete Position in der 3D-Szene
    var connectionCount: Int // Anzahl eingehender + ausgehender Links
}

// Eine gerichtete Kante – entspricht einem [[wikilink]]
struct GraphEdge: Sendable {
    let sourceID: String
    let targetID: String
}

// Verwaltet den gesamten Graphen und startet die Layout-Berechnung
@MainActor
class GraphModel: ObservableObject {
    @Published var nodes: [GraphNode] = []
    @Published var edges: [GraphEdge] = []
    @Published var isLoading: Bool = false
    @Published var loadingProgress: Double = 0.0
    @Published var errorMessage: String?

    // Baut den Graphen aus einem Array von Notizen auf
    func build(from notes: [Note]) async {
        await Task.yield() // UI-Update-Chance vor der Berechnung
        let (computedNodes, computedEdges) = GraphModel.computeLayout(from: notes)
        self.nodes = computedNodes
        self.edges = computedEdges
    }

    // Berechnet Knoten-Positionen via Force-Directed Layout (läuft auf Hintergrund-Thread)
    nonisolated static func computeLayout(from notes: [Note]) -> ([GraphNode], [GraphEdge]) {
        guard !notes.isEmpty else { return ([], []) }

        // Lookup: Note-Name (lowercase) → Array-Index (bei Namenskollision erste Datei gewinnt)
        let nameToIndex: [String: Int] = Dictionary(
            notes.enumerated().map { ($1.name.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )

        // Kanten aufbauen + Verbindungszähler pflegen
        var edgeList: [GraphEdge] = []
        var connectionCounts = [Int](repeating: 0, count: notes.count)

        for (i, note) in notes.enumerated() {
            for link in note.links {
                let key = link.lowercased()
                guard let j = nameToIndex[key], j != i else { continue }
                edgeList.append(GraphEdge(sourceID: note.id, targetID: notes[j].id))
                connectionCounts[i] += 1
                connectionCounts[j] += 1
            }
        }

        // Initiale Positionen: Fibonacci-Kugel für gleichmäßige Startverteilung
        let goldenRatio = Float((1.0 + sqrt(5.0)) / 2.0)
        let n = notes.count
        var positions: [SIMD3<Float>] = (0..<n).map { i in
            let theta = 2.0 * Float.pi * Float(i) / goldenRatio
            let phi   = acos(1.0 - 2.0 * Float(i + 1) / Float(n + 1))
            let r: Float = 5.0
            return SIMD3<Float>(r * sin(phi) * cos(theta),
                                r * sin(phi) * sin(theta),
                                r * cos(phi))
        }

        // Force-Directed Layout: 50 Iterationen
        let indexMap: [String: Int] = Dictionary(uniqueKeysWithValues: notes.enumerated().map { ($1.id, $0) })
        var velocities = [SIMD3<Float>](repeating: .zero, count: n)
        let repK: Float  = 3.0   // Abstoßungskonstante
        let attK: Float  = 0.08  // Anziehungskonstante (entlang Kanten)
        let gravK: Float = 0.05  // Schwerkraft zur Mitte (verhindert Auseinanderdriften)
        let damp: Float  = 0.80  // Dämpfung (simuliert Reibung)
        let dt: Float    = 0.1   // Zeitschritt

        for _ in 0..<50 {
            var forces = [SIMD3<Float>](repeating: .zero, count: n)

            // Abstoßung: jedes Knotenpaar stößt sich ab (Coulomb-analog)
            for i in 0..<n {
                for j in (i + 1)..<n {
                    let delta = positions[i] - positions[j]
                    let dist  = max(simd_length(delta), 0.1)
                    let f     = repK / (dist * dist)
                    let dir   = delta / dist
                    forces[i] += dir * f
                    forces[j] -= dir * f
                }
                // Schwerkraft zieht Knoten zur Szene-Mitte
                forces[i] -= positions[i] * gravK
            }

            // Anziehung: verbundene Knoten ziehen sich an (Hooke-analog)
            for edge in edgeList {
                guard let si = indexMap[edge.sourceID],
                      let ti = indexMap[edge.targetID] else { continue }
                let delta = positions[ti] - positions[si]
                let dist  = max(simd_length(delta), 0.1)
                let f     = attK * dist
                let dir   = delta / dist
                forces[si] += dir * f
                forces[ti] -= dir * f
            }

            // Velocity-Verlet-Integration + Dämpfung
            for i in 0..<n {
                velocities[i] = (velocities[i] + forces[i] * dt) * damp
                positions[i] += velocities[i] * dt
            }
        }

        // SIMD3<Float> → GraphNode mit SCNVector3
        let nodeList: [GraphNode] = notes.enumerated().map { (i, note) in
            let p = positions[i]
            return GraphNode(
                id: note.id,
                title: note.name,
                position: SCNVector3(p.x, p.y, p.z),
                connectionCount: connectionCounts[i]
            )
        }

        return (nodeList, edgeList)
    }
}
