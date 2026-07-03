//
//  SessionCheckView.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 2.07.2026.
//

import SwiftUI

struct SessionCheckView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.text.bubble.right.fill")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            ProgressView()
                .controlSize(.regular)

            Text("Oturum kontrol ediliyor…")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SessionCheckView()
        .frame(width: 600, height: 500)
}
