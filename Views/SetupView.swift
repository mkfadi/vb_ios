//
//  SetupView.swift
//  vb_ios

import SwiftUI

struct SetupView: View {
    @EnvironmentObject var viewModel: AppViewModel

    @State private var token     = ""
    @State private var repoPath  = ""
    @State private var isLoading = false
    @State private var errorMsg: String?

    var body: some View {
        ZStack {
            // Dawn gradient
            LinearGradient(
                colors: [Color(red: 0.165, green: 0.082, blue: 0.314), .vbDeep, .vbVoid],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // Faint nebula bloom
            RadialGradient(
                colors: [Color.vbLavender.opacity(0.12), .clear],
                center: UnitPoint(x: 0.30, y: 0.18),
                startRadius: 0, endRadius: 260
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Hero
                    VStack(spacing: 16) {
                        PearlView(size: 88)
                        Text("Virtual Brain")
                            .font(.system(size: 38, weight: .medium, design: .serif))
                            .foregroundColor(.vbFg1)
                            .tracking(-0.8)
                        Text("Verbinde deinen Obsidian Vault mit GitHub.")
                            .font(.system(size: 16, design: .serif))
                            .italic()
                            .foregroundColor(.vbFg2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 260)
                    }
                    .padding(.top, 72)
                    .padding(.bottom, 40)

                    // Input card
                    VStack(spacing: 18) {
                        inputField(
                            label: "Personal Access Token",
                            icon: "key.fill",
                            placeholder: "ghp_xxxxxxxxxxxxxxxxxxxx",
                            text: $token,
                            secure: true
                        )
                        inputField(
                            label: "Repository (owner/repo)",
                            icon: "folder.fill",
                            placeholder: "dein-user/mein-obsidian-vault",
                            text: $repoPath,
                            secure: false
                        )

                        if let err = errorMsg {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.vbDanger)
                                    .font(.system(size: 12))
                                Text(err)
                                    .foregroundColor(.vbDanger)
                                    .font(.system(size: 12))
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.vbDanger.opacity(0.10))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.vbDanger.opacity(0.30), lineWidth: 1)
                            )
                        }

                        // Aurora CTA
                        Button { Task { await connect() } } label: {
                            Group {
                                if isLoading {
                                    ProgressView()
                                        .tint(Color(red: 0.102, green: 0.039, blue: 0.227))
                                } else {
                                    Text("Verbinden und laden")
                                        .font(.system(size: 15, weight: .bold))
                                        .tracking(-0.3)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .foregroundColor(Color(red: 0.102, green: 0.039, blue: 0.227))
                            .background(
                                canConnect
                                ? LinearGradient(
                                    colors: [.vbPink, .vbLavender, .vbPeriwinkle],
                                    startPoint: .leading, endPoint: .trailing
                                  )
                                : LinearGradient(
                                    colors: [Color.vbFg4],
                                    startPoint: .leading, endPoint: .trailing
                                  )
                            )
                            .cornerRadius(14)
                            .shadow(color: canConnect ? Color.vbPink.opacity(0.45) : .clear,
                                    radius: 14, y: 3)
                        }
                        .disabled(!canConnect || isLoading)
                        .padding(.top, 4)
                    }
                    .padding(22)
                    .background(Color(red: 0.071, green: 0.031, blue: 0.149).opacity(0.60))
                    .cornerRadius(22)
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color.vbLavender.opacity(0.18), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.55), radius: 20, y: 6)
                    .padding(.horizontal, 24)

                    // Permission hint
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Token braucht folgende Berechtigung:")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.vbFg4)
                            .tracking(0.4)
                        Text("· repo: Contents lesen und schreiben")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.vbFg4)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 28)
                    .padding(.top, 22)
                    .padding(.bottom, 48)
                }
            }
        }
    }

    @ViewBuilder
    private func inputField(
        label: String, icon: String, placeholder: String,
        text: Binding<String>, secure: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.vbLavender)
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.vbFg3)
                    .tracking(0.4)
            }
            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .font(.system(size: 13, design: .monospaced))
            .padding(14)
            .foregroundColor(.vbFg1)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.vbLavender.opacity(0.22), lineWidth: 1)
            )
        }
    }

    private var canConnect: Bool {
        !token.trimmingCharacters(in: .whitespaces).isEmpty &&
        !repoPath.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func connect() async {
        errorMsg  = nil
        isLoading = true
        do {
            try await viewModel.setup(
                token:   token.trimmingCharacters(in: .whitespaces),
                repo:    repoPath.trimmingCharacters(in: .whitespaces)
            )
        } catch {
            errorMsg = error.localizedDescription
        }
        isLoading = false
    }
}
