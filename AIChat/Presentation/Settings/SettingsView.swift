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

    init(viewModel: SettingsViewModel, session: AuthSession) {
        _viewModel = State(initialValue: viewModel)
        self.session = session
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                providerList
                    .frame(width: 240)

                Divider()

                settingsForm
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            feedbackArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.default, value: viewModel.infoMessage)
        .animation(.default, value: viewModel.errorMessage)
    }

    private var providerList: some View {
        VStack(spacing: 0) {
            List(selection: Bindable(viewModel).selectedProviderID) {
                ForEach(viewModel.providerConfigs) { provider in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(provider.name)
                            .lineLimit(1)
                        Text(provider.baseURL.host() ?? provider.baseURL.absoluteString)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .tag(Optional(provider.id))
                }
            }

            Divider()

            HStack {
                Button {
                    viewModel.addProvider()
                } label: {
                    Label("Ekle", systemImage: "plus")
                }

                Spacer()
            }
            .padding(10)
        }
    }

    private var settingsForm: some View {
        Form {
            Section("Varsayılan Model") {
                Picker("Yeni sohbet modeli", selection: Bindable(viewModel).selectedModelTag) {
                    ForEach(viewModel.providerSections) { section in
                        Section(section.name) {
                            ForEach(section.models) { model in
                                Text(model.displayName)
                                    .tag(SettingsViewModel.tag(
                                        providerID: model.providerID,
                                        modelID: model.id
                                    ))
                            }
                        }
                    }
                }
                .disabled(viewModel.providerSections.allSatisfy { $0.models.isEmpty })
            }

            Section("Sağlayıcı") {
                if viewModel.selectedProvider == nil {
                    ContentUnavailableView(
                        "Sağlayıcı yok",
                        systemImage: "server.rack",
                        description: Text("Yeni sohbet başlatmak için bir sağlayıcı ekleyin.")
                    )
                } else {
                    TextField("Ad", text: Bindable(viewModel).providerNameDraft)
                        .textFieldStyle(.roundedBorder)

                    TextField("Base URL", text: Bindable(viewModel).baseURLDraft)
                        .textFieldStyle(.roundedBorder)

                    Toggle("API anahtarı gerekiyor", isOn: Bindable(viewModel).requiresAPIKeyDraft)

                    HStack {
                        Button("Kaydet") {
                            viewModel.saveSelectedProvider()
                        }
                        .disabled(!viewModel.canSaveProvider)

                        Button("Sil", role: .destructive) {
                            viewModel.deleteSelectedProvider()
                        }

                        Spacer()
                    }
                }
            }

            if viewModel.selectedProvider != nil {
                Section("Modeller") {
                    TextEditor(text: Bindable(viewModel).modelsDraft)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 120)
                }

                Section("API Anahtarı") {
                    LabeledContent("Durum") {
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
                        .disabled(!(viewModel.selectedProvider?.requiresAPIKey ?? true))

                    HStack {
                        Button("Kaydet") {
                            viewModel.saveAPIKey()
                        }
                        .disabled(
                            viewModel.apiKeyDraft
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                                .isEmpty
                        )

                        if viewModel.hasStoredAPIKey {
                            Button("Anahtarı Sil", role: .destructive) {
                                viewModel.deleteAPIKey()
                            }
                        }

                        Spacer()
                    }
                    .disabled(!(viewModel.selectedProvider?.requiresAPIKey ?? true))
                }
            }

            Section("Hesap") {
                LabeledContent("Kullanıcı", value: session.displayName ?? session.userID)
                if let email = session.email {
                    LabeledContent("E-posta", value: email)
                }
                LabeledContent("Sağlayıcı", value: session.providerID)

                Button("Çıkış Yap", role: .destructive) {
                    Task { await viewModel.logout() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
    }

    private var feedbackArea: some View {
        VStack(spacing: 0) {
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
                .frame(maxWidth: 760)
            }
        }
    }
}

#Preview {
    let store = UserDefaultsProviderConfigStore(
        defaults: UserDefaults(suiteName: "AIChat.settings.preview")!
    )
    let config = ProviderConfig(
        name: "Local LLM",
        baseURL: URL(string: "http://localhost:11434/v1")!,
        requiresAPIKey: false,
        models: [.init(id: "llama3")]
    )
    store.save(config)

    return SettingsView(
        viewModel: SettingsViewModel(
            secureStore: InMemorySecureStore(),
            registry: ConfigBackedAIProviderRegistry(
                configStore: store,
                secureStore: InMemorySecureStore()
            ),
            providerConfigStore: store,
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
    .frame(width: 900, height: 620)
}
