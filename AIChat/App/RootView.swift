//
//  RootView.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 2.07.2026.
//
//  The only view that knows about top-level routing.
//  checkingSession → SessionCheckView
//  loggedOut       → LoginView
//  loggedIn        → MainWindowView (placeholder for now)
//

import SwiftUI

struct RootView: View {

    @State private var viewModel: RootViewModel
    private let dependencies: AppDependencies

    init(dependencies: AppDependencies) {
        self.dependencies = dependencies
        _viewModel = State(
            initialValue: RootViewModel(authService: dependencies.authService)
        )
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .checkingSession:
                SessionCheckView()

            case .loggedOut:
                LoginView(
                    viewModel: LoginViewModel(authService: dependencies.authService)
                )

            case .loggedIn(let session):
                MainWindowView(session: session, dependencies: dependencies)
            }
        }
        .task { await viewModel.start() }
        .animation(.default, value: viewModel.state)
    }
}

// MARK: - Temporary placeholder (replaced in the Chat phase)

#Preview("Full flow (mock)") {
    RootView(dependencies: .makePreview(auth: .init(latency: .seconds(1))))
        .frame(width: 700, height: 500)
}
