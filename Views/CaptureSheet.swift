// CaptureSheet.swift - Quick note capture for Synaptic Vault

import SwiftUI

struct CaptureSheet: View {
    @EnvironmentObject private var viewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?

    let onCreated: (String) -> Void
    let onError: (String) -> Void

    @State private var title = ""
    @State private var bodyText = ""
    @State private var selectedType = "reference"
    @State private var sendToInbox = true
    @State private var targetFolder = "inbox"
    @State private var isSaving = false
    @State private var errorMessage: String?

    private enum Field {
        case title
    }

    private let types = ["project", "concept", "reference", "experiment", "goal"]

    private var folders: [String] {
        let values = viewModel.topLevelFolders
        return values.isEmpty ? ["inbox"] : values
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSaving
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $title)
                        .focused($focusedField, equals: .title)
                        .textInputAutocapitalization(.words)
                        .submitLabel(.next)

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $bodyText)
                            .frame(minHeight: 150)
                            .font(.system(size: 14, design: .monospaced))
                            .scrollContentBackground(.hidden)

                        if bodyText.isEmpty {
                            Text("Body")
                                .font(.system(size: 14))
                                .foregroundColor(.vbFg4)
                                .padding(.top, 8)
                                .padding(.leading, 5)
                                .allowsHitTesting(false)
                        }
                    }
                }

                Section {
                    Picker("Type", selection: $selectedType) {
                        ForEach(types, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }

                    Toggle("Send to inbox/", isOn: $sendToInbox)
                        .tint(.vbPink)

                    if !sendToInbox {
                        Picker("Zielordner", selection: $targetFolder) {
                            ForEach(folders, id: \.self) { folder in
                                Text(folder).tag(folder)
                            }
                        }
                    }
                }

                if let errorMessage {
                    Section {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.vbDanger)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.vbDeep.ignoresSafeArea())
            .navigationTitle("Quick Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Abbrechen") { dismiss() }
                        .foregroundColor(.vbLavender)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(.vbPink)
                        } else {
                            Text("Speichern")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(!canSave)
                    .foregroundColor(canSave ? .vbPink : .vbFg4)
                }
            }
            .onAppear {
                targetFolder = folders.first ?? "inbox"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    focusedField = .title
                }
            }
        }
        .presentationCornerRadius(28)
        .presentationBackground(Color.vbDeep)
    }

    private func save() async {
        guard canSave else { return }
        isSaving = true
        errorMessage = nil
        do {
            let path = try await viewModel.createCapturedNote(
                title: title,
                body: bodyText,
                type: selectedType,
                sendToInbox: sendToInbox,
                folder: targetFolder
            )
            await MainActor.run {
                onCreated(path)
                dismiss()
            }
        } catch {
            let message = error.localizedDescription
            await MainActor.run {
                errorMessage = message
                onError(message)
            }
        }
        isSaving = false
    }
}
