// SetupView.swift – Ersteinstieg: GitHub Token und Repo eingeben

import SwiftUI

struct SetupView: View {
    @EnvironmentObject var viewModel: AppViewModel

    @State private var token      = ""
    @State private var repoPath   = ""
    @State private var isLoading  = false
    @State private var errorMsg: String?

    var body: some View {
        ZStack {
            // Dunkler Verlauf-Hintergrund passend zum "Gehirn"-Thema
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.0, blue: 0.12), .black],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 36) {

                    // Header mit App-Icon
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [.purple, .blue],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 90, height: 90)
                                .blur(radius: 20)
                                .opacity(0.6)
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 56, weight: .thin))
                                .foregroundStyle(LinearGradient(
                                    colors: [.purple, .cyan],
                                    startPoint: .topLeading, endPoint: .bottomTrailing))
                        }
                        Text("Virtual Brain")
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)
                        Text("Verbinde deinen Obsidian Vault mit GitHub")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 52)

                    // Eingabe-Karte
                    VStack(spacing: 20) {

                        // Token-Feld (verdeckt wie Passwort)
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Personal Access Token", systemImage: "key.fill")
                                .font(.caption.bold())
                                .foregroundColor(.gray)
                            SecureField("ghp_xxxxxxxxxxxxxxxxxxxx", text: $token)
                                .padding(14)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.purple.opacity(0.4), lineWidth: 1)
                                )
                        }

                        // Repo-Pfad-Feld
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Repository (owner/repo)", systemImage: "folder.fill")
                                .font(.caption.bold())
                                .foregroundColor(.gray)
                            TextField("dein-user/mein-obsidian-vault", text: $repoPath)
                                .padding(14)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(12)
                                .foregroundColor(.white)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.purple.opacity(0.4), lineWidth: 1)
                                )
                        }

                        // Fehlermeldung
                        if let err = errorMsg {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                Text(err)
                                    .foregroundColor(.red)
                                    .font(.caption)
                            }
                            .padding(12)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }

                        // Verbinden-Button
                        Button {
                            Task { await connect() }
                        } label: {
                            Group {
                                if isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    Text("Verbinden und laden")
                                        .font(.headline)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .background(
                                canConnect
                                ? LinearGradient(colors: [.purple, .blue], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [.gray], startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundColor(.white)
                            .cornerRadius(14)
                        }
                        .disabled(!canConnect || isLoading)
                    }
                    .padding(20)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)

                    // Hinweis zu benötigten Token-Berechtigungen
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Token braucht folgende Berechtigung:")
                            .font(.caption.bold())
                            .foregroundColor(.gray)
                        Text("• repo: Contents lesen und schreiben")
                            .font(.caption)
                            .foregroundColor(.gray.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 32)
                }
            }
        }
    }

    private var canConnect: Bool {
        !token.trimmingCharacters(in: .whitespaces).isEmpty &&
        !repoPath.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // Verbindet mit GitHub, validiert Credentials und navigiert zur Brain-View
    private func connect() async {
        errorMsg  = nil
        isLoading = true
        do {
            try await viewModel.setup(
                token: token.trimmingCharacters(in: .whitespaces),
                repo:  repoPath.trimmingCharacters(in: .whitespaces)
            )
        } catch {
            errorMsg = error.localizedDescription
        }
        isLoading = false
    }
}
