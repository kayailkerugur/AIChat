//
//  SettingsView.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 6.07.2026.
//

import SwiftUI

struct SettingsView: View {

    @State private var viewModel: SettingsViewModel
    let session: AuthSession

    @Environment(\.dismiss) private var dismiss

    init(viewModel: SettingsViewModel, session: AuthSession) {
        _viewModel = State(initialValue: viewModel)
        self.session = session
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                // MARK: AI configuration
                Section("Yapay Zekâ") {
                    Picker("Varsayılan model", selection: Bindable(viewModel).selectedModelID) {
                        ForEach(viewModel.availableModels) { model in
                            Text(model.displayName).tag(model.id)
                        }
                    }
                    .help("Yeni sohbetlerde kullanılacak model. Mevcut sohbetler kendi modelini korur.")

                    LabeledContent("API anahtarı") {
                        HStack(spacing: 8) {
                            Image(systemName: viewModel.hasStoredAPIKey
                                  ? "checkmark.seal.fill" : "xmark.seal")
                                .foregroundStyle(viewModel.hasStoredAPIKey ? .green : .secondary)
                            Text(viewModel.hasStoredAPIKey ? "Kayıtlı (Keychain)" : "Kayıtlı değil")
                                .foregroundStyle(.secondary)
                        }
                    }

                    SecureField("Yeni API anahtarı girin", text: Bindable(viewModel).apiKeyDraft)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button("Kaydet") { viewModel.saveAPIKey() }
                            .disabled(viewModel.apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                        if viewModel.hasStoredAPIKey {
                            Button("Anahtarı Sil", role: .destructive) {
                                viewModel.deleteAPIKey()
                            }
                        }

                        Spacer()

                        Link("Anahtar al (AI Studio)",
                             destination: URL(string: "https://aistudio.google.com/apikey")!)
                            .font(.callout)
                    }
                }

                // MARK: Profile
                Section("Hesap") {
                    LabeledContent("Kullanıcı", value: session.displayName ?? session.userID)
                    if let email = session.email {
                        LabeledContent("E-posta", value: email)
                    }
                    LabeledContent("Sağlayıcı", value: session.providerID)

                    Button("Çıkış Yap", role: .destructive) {
                        Task {
                            await viewModel.logout()
                            dismiss()
                        }
                    }
                }
            }
            .formStyle(.grouped)

            // MARK: Feedback banners
            if let info = viewModel.infoMessage {
                Label(info, systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.green)
                    .padding(.vertical, 8)
                    .transition(.opacity)
            }
            if let error = viewModel.errorMessage {
                ErrorBannerView(message: error) {
                    viewModel.dismissMessages()
                }
                .padding([.horizontal, .bottom], 12)
            }
        }
        .frame(width: 480, height: 420)
        .navigationTitle("Ayarlar")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Kapat") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .animation(.default, value: viewModel.infoMessage)
        .animation(.default, value: viewModel.errorMessage)
    }
}

#Preview {
    SettingsView(
        viewModel: SettingsViewModel(
            secureStore: InMemorySecureStore(),
            aiProvider: MockAIProvider(),
            authService: MockAuthService()
        ),
        session: AuthSession(
            userID: "preview",
            displayName: "Test Kullanıcısı",
            email: "test@example.com",
            providerID: "mock",
            expiresAt: nil
        )
    )
}
