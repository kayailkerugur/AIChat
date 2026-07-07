//
//  PKCEGenerator.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 7.07.2026.
//
//  PKCE (RFC 7636) primitives for the OAuth Authorization Code flow.
//  Pure functions over CryptoKit — no I/O, fully unit-testable,
//  including against the RFC's own test vector.
//
//  Why PKCE matters here: a native app is a PUBLIC client — it cannot
//  keep a client secret. PKCE binds the authorization code to this
//  app instance: even if the code is intercepted via the custom URL
//  scheme, it is useless without the verifier that never left memory.
//

import Foundation
import CryptoKit

struct PKCEPair: Equatable {
    /// High-entropy random string — sent ONLY in the token exchange.
    let verifier: String
    /// base64url(SHA256(verifier)) — sent in the authorization request.
    let challenge: String
    /// Always "S256"; the "plain" method is not used.
    let method = "S256"
}

enum PKCEGenerator {

    /// RFC 7636 §4.1: verifier is 43–128 chars of [A-Z a-z 0-9 - . _ ~].
    /// 32 random bytes → 43 base64url chars, the recommended minimum
    /// entropy.
    static func makePair() -> PKCEPair {
        var bytes = [UInt8](repeating: 0, count: 32)
        // SecRandomCopyBytes is the platform CSPRNG. Failure is
        // practically impossible; fall back to SystemRandomNumberGenerator
        // (also cryptographically secure on Apple platforms) if it ever does.
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) != errSecSuccess {
            var generator = SystemRandomNumberGenerator()
            bytes = (0..<32).map { _ in UInt8.random(in: .min ... .max, using: &generator) }
        }

        let verifier = base64URLEncode(Data(bytes))
        return PKCEPair(
            verifier: verifier,
            challenge: challenge(forVerifier: verifier)
        )
    }

    /// RFC 7636 §4.2: challenge = BASE64URL(SHA256(ASCII(verifier)))
    static func challenge(forVerifier verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return base64URLEncode(Data(digest))
    }

    /// Base64url without padding (RFC 4648 §5).
    static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
