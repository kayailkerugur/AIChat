//
//  OAuthCallbackTests.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 7.07.2026.
//
//  Tests the pure callback-validation logic. The state-mismatch case
//  is a SECURITY test: a callback with the wrong state is a potential
//  CSRF/injection attempt and must be rejected before any token
//  exchange happens (spec §3.1: "OAuth state değeri doğrulanmalı").
//

import XCTest
@testable import AIChatSDK

final class OAuthCallbackTests: XCTestCase {

    private let scheme = "com.googleusercontent.apps.test"

    private func callback(_ query: String) -> URL {
        URL(string: "\(scheme):/oauth2redirect?\(query)")!
    }

    func test_validCallback_returnsAuthorizationCode() throws {
        let url = callback("code=abc123&state=STATE1")

        let code = try OAuthService.authorizationCode(
            fromCallback: url, expectedState: "STATE1"
        )

        XCTAssertEqual(code, "abc123")
    }

    func test_stateMismatch_throwsInvalidCallback() {
        let url = callback("code=abc123&state=ATTACKER")

        XCTAssertThrowsError(
            try OAuthService.authorizationCode(fromCallback: url, expectedState: "STATE1")
        ) { error in
            XCTAssertEqual(error as? AuthError, .invalidCallback)
        }
    }

    func test_missingState_throwsInvalidCallback() {
        let url = callback("code=abc123")

        XCTAssertThrowsError(
            try OAuthService.authorizationCode(fromCallback: url, expectedState: "STATE1")
        ) { error in
            XCTAssertEqual(error as? AuthError, .invalidCallback)
        }
    }

    func test_missingCode_throwsInvalidCallback() {
        let url = callback("state=STATE1")

        XCTAssertThrowsError(
            try OAuthService.authorizationCode(fromCallback: url, expectedState: "STATE1")
        ) { error in
            XCTAssertEqual(error as? AuthError, .invalidCallback)
        }
    }

    func test_accessDenied_throwsCancelledByUser() {
        let url = callback("error=access_denied&state=STATE1")

        XCTAssertThrowsError(
            try OAuthService.authorizationCode(fromCallback: url, expectedState: "STATE1")
        ) { error in
            XCTAssertEqual(error as? AuthError, .cancelledByUser)
        }
    }

    func test_otherProviderError_throwsUnauthorized() {
        let url = callback("error=server_error&state=STATE1")

        XCTAssertThrowsError(
            try OAuthService.authorizationCode(fromCallback: url, expectedState: "STATE1")
        ) { error in
            XCTAssertEqual(error as? AuthError, .unauthorized)
        }
    }

    func test_stateTokens_areUniqueAndURLSafe() {
        let first = OAuthService.randomStateToken()
        let second = OAuthService.randomStateToken()

        XCTAssertNotEqual(first, second)
        XCTAssertFalse(first.contains("+"))
        XCTAssertFalse(first.contains("/"))
        XCTAssertFalse(first.contains("="))
    }

    func test_formEncodedBody_percentEncodesReservedCharacters() {
        let body = OAuthService.formEncodedBody(["redirect_uri": "com.app:/x y&z"])
        let encoded = String(decoding: body, as: UTF8.self)

        XCTAssertEqual(encoded, "redirect_uri=com.app%3A%2Fx%20y%26z")
    }
}
