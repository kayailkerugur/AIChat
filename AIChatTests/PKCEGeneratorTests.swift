//
//  PKCEGeneratorTests.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 7.07.2026.
//
//  Includes the official RFC 7636 Appendix B test vector — if the
//  challenge derivation is wrong, Google's token endpoint rejects
//  the exchange with an opaque error, so proving correctness here
//  saves painful debugging later.
//

import XCTest
@testable import AIChat

final class PKCEGeneratorTests: XCTestCase {

    /// RFC 7636 Appendix B: the spec's own verifier→challenge example.
    func test_challenge_matchesRFC7636TestVector() {
        let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"

        let challenge = PKCEGenerator.challenge(forVerifier: verifier)

        XCTAssertEqual(challenge, "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    func test_verifier_lengthIsWithinRFCBounds() {
        let pair = PKCEGenerator.makePair()

        // 32 random bytes → exactly 43 base64url chars (RFC minimum).
        XCTAssertGreaterThanOrEqual(pair.verifier.count, 43)
        XCTAssertLessThanOrEqual(pair.verifier.count, 128)
    }

    func test_verifier_usesOnlyUnreservedCharacters() {
        let allowed = CharacterSet(
            charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
                + "abcdefghijklmnopqrstuvwxyz"
                + "0123456789-._~"
        )
        let pair = PKCEGenerator.makePair()

        XCTAssertTrue(
            pair.verifier.unicodeScalars.allSatisfy { allowed.contains($0) },
            "verifier contains characters outside RFC 7636 unreserved set"
        )
    }

    func test_challenge_isDerivedFromVerifier() {
        let pair = PKCEGenerator.makePair()

        XCTAssertEqual(
            pair.challenge,
            PKCEGenerator.challenge(forVerifier: pair.verifier)
        )
        XCTAssertEqual(pair.method, "S256")
    }

    func test_consecutivePairs_areUnique() {
        let first = PKCEGenerator.makePair()
        let second = PKCEGenerator.makePair()

        XCTAssertNotEqual(first.verifier, second.verifier)
        XCTAssertNotEqual(first.challenge, second.challenge)
    }

    func test_base64URL_hasNoPaddingOrReservedChars() {
        // 1 byte → base64 "AQ==" → base64url "AQ"
        let encoded = PKCEGenerator.base64URLEncode(Data([1]))

        XCTAssertFalse(encoded.contains("="))
        XCTAssertFalse(encoded.contains("+"))
        XCTAssertFalse(encoded.contains("/"))
    }
}
