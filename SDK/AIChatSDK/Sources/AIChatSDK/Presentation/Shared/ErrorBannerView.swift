//
//  ErrorBannerView.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 6.07.2026.
//
//  Dismissible error banner used across Login, Chat and Sidebar —
//  one visual language for every user-visible error (acceptance
//  criterion 13: auth, network and persistence errors must be
//  shown to the user in an understandable way).
//

import SwiftUI

public struct ErrorBannerView: View {

    let message: String
    let onDismiss: () -> Void
    @Environment(\.aiChatTheme) private var theme

    public init(message: String, onDismiss: @escaping () -> Void) {
        self.message = message
        self.onDismiss = onDismiss
    }

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(theme.warningColor)

            Text(message)
                .font(theme.supportingFont)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hata mesajını kapat")
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        .transition(.opacity)
    }
}

#Preview {
    ErrorBannerView(message: "Mesaj kaydedilemedi. Sohbet geçmişiniz eksik olabilir.") {}
        .padding()
        .frame(width: 420)
}
