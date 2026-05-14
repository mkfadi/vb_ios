// vb_iosApp.swift – Einstiegspunkt: verbindet alle Schichten der App

import SwiftUI

@main
struct vb_iosApp: App {

    // AppViewModel lebt auf App-Ebene – so lange wie die App selbst
    @StateObject private var viewModel = AppViewModel()

    // Lifecycle-Phasen (active / inactive / background) beobachten
    @Environment(\.scenePhase) private var scenePhase

    init() {
        configureGlobalAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // viewModel einmal hier injecten – alle Child-Views erben es automatisch
                .environmentObject(viewModel)
                // Helles Brand-Theme passend zum Synaptic-Vault-Logo
                .preferredColorScheme(.light)
        }
        // Wenn die App aus dem Hintergrund zurückkehrt und Notizen leer sind: neu laden
        .onChange(of: scenePhase) { _, phase in
            if phase == .active,
               viewModel.isSetupComplete,
               viewModel.graphModel.nodes.isEmpty,
               !viewModel.graphModel.isLoading {
                Task { await viewModel.loadNotes() }
            }
        }
    }

    // Setzt globale UIKit-Styles bevor die erste View erscheint
    private func configureGlobalAppearance() {

        // Navigation Bar – warmes Weiß, dunkle Titel, pinke Aktionen
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(red: 1.00, green: 0.965, blue: 0.982, alpha: 1)
        nav.titleTextAttributes = [
            .foregroundColor: UIColor(red: 0.18, green: 0.09, blue: 0.15, alpha: 1),
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        nav.largeTitleTextAttributes = [
            .foregroundColor: UIColor(red: 0.18, green: 0.09, blue: 0.15, alpha: 1)
        ]
        // Trennlinie entfernen
        nav.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance   = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance    = nav
        UINavigationBar.appearance().tintColor = UIColor(red: 0.94, green: 0.07, blue: 0.48, alpha: 1)

        // Sheet-Hintergrund (für NoteView) ebenfalls hell
        UITableView.appearance().backgroundColor = UIColor(red: 1.00, green: 0.975, blue: 0.988, alpha: 1)
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self])
            .tintColor = UIColor(red: 0.94, green: 0.07, blue: 0.48, alpha: 1)
    }
}
