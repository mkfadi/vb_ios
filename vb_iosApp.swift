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
                // App läuft immer im Dark-Mode (passend zum Gehirn-Look)
                .preferredColorScheme(.dark)
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

        // Navigation Bar – dunkler Hintergrund, weißer Titel, lila Buttons
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(red: 0.05, green: 0.02, blue: 0.12, alpha: 1)
        nav.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        nav.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        // Trennlinie entfernen
        nav.shadowColor = .clear
        UINavigationBar.appearance().standardAppearance   = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance    = nav
        UINavigationBar.appearance().tintColor = UIColor.systemPurple

        // Sheet-Hintergrund (für NoteView) ebenfalls dunkel
        UITableView.appearance().backgroundColor = .black
        UIView.appearance(whenContainedInInstancesOf: [UIAlertController.self])
            .tintColor = UIColor.systemPurple
    }
}
