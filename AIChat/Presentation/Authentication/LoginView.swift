//
//  LoginView.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 2.07.2026.
//

import SwiftUI
import AIChatSDK

struct LoginView: View {

    @State private var viewModel: LoginViewModel

    init(viewModel: LoginViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // App identity
            VStack(spacing: 8) {
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)

                Text("AI Chat")
                    .font(.largeTitle.bold())

                Text("Devam etmek için giriş yapın")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            // Login action
            Button {
                viewModel.loginTapped()
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isLoggingIn {
                        ProgressView()
                            .controlSize(.small)
                    }
                    Text(viewModel.isLoggingIn ? "Giriş yapılıyor…" : "Giriş Yap")
                        .frame(minWidth: 140)
                }
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoggingIn)
            .keyboardShortcut(.defaultAction) // Enter triggers login (macOS nicety)

            // Error banner
            if let message = viewModel.errorMessage {
                ErrorBannerView(message: message) {
                    viewModel.dismissError()
                }
                .frame(maxWidth: 420)
                .transition(.opacity)
            }

            Spacer()

            // Privacy note (required by the screen table in the spec)
            Text("Giriş bilgileriniz sistem tarayıcısı üzerinden sağlayıcıya iletilir; parolanız bu uygulama tarafından görülmez veya saklanmaz.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
                .padding(.bottom, 24)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.default, value: viewModel.errorMessage)
    }
}

#Preview("Idle") {
    LoginView(
        viewModel: LoginViewModel(
            authService: MockAuthService(behavior: .init(latency: .seconds(2)))
        )
    )
    .frame(width: 600, height: 500)
}

#Preview("Login fails (network)") {
    LoginView(
        viewModel: LoginViewModel(
            authService: MockAuthService(
                behavior: .init(latency: .seconds(1), loginFailure: .network)
            )
        )
    )
    .frame(width: 600, height: 500)
}
