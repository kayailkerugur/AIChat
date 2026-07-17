//
//  RootViewModelTests.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 7.07.2026.
//

import XCTest
@testable import AIChatSDK

@MainActor
final class RootViewModelTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // MockAuthService simulates persisted sessions via this flag —
        // clear it so tests are order-independent.
        UserDefaults.standard.removeObject(forKey: "mock.auth.hasSession")
    }

    private func waitUntil(
        timeout: TimeInterval = 2,
        _ description: String,
        _ condition: @escaping () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                XCTFail("Timed out waiting for: \(description)")
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    func test_noStoredSession_routesToLoginWithoutVisibleError() async {
        let auth = MockAuthService(behavior: .init(latency: .zero))
        let viewModel = RootViewModel(authService: auth)

        await viewModel.start()

        XCTAssertEqual(viewModel.state, .loggedOut(reason: .noStoredSession))
        // The reason exists but is benign — it must not produce a banner.
        XCTAssertNil(AuthError.noStoredSession.errorDescription)
    }

    func test_expiredSession_routesToLoginWithExpiredReason() async {
        let auth = MockAuthService(
            behavior: .init(latency: .zero, restoreFailure: .sessionExpired)
        )
        let viewModel = RootViewModel(authService: auth)

        await viewModel.start()

        XCTAssertEqual(viewModel.state, .loggedOut(reason: .sessionExpired))
        // This one DOES carry a user-facing message (spec §8 error state).
        XCTAssertNotNil(AuthError.sessionExpired.errorDescription)
    }

    func test_loginPublishingSession_routesToMain() async throws {
        let auth = MockAuthService(
            behavior: .init(latency: .zero, simulatesPersistedSession: false)
        )
        let viewModel = RootViewModel(authService: auth)
        await viewModel.start()

        let session = try await auth.login()

        try await waitUntil("routing to loggedIn") {
            viewModel.state == .loggedIn(session)
        }
    }

    func test_logout_routesBackToLoginWithoutReason() async throws {
        let auth = MockAuthService(
            behavior: .init(latency: .zero, simulatesPersistedSession: false)
        )
        let viewModel = RootViewModel(authService: auth)
        await viewModel.start()
        let session = try await auth.login()
        try await waitUntil("login routing") {
            viewModel.state == .loggedIn(session)
        }

        await auth.logout()

        try await waitUntil("logout routing") {
            viewModel.state == .loggedOut(reason: nil)
        }
    }
}
