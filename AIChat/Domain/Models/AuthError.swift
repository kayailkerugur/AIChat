//
//  AuthError.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 2.07.2026.
//

import Foundation

enum AuthError: Error, Equatable {
    /// User dismissed the login sheet / ASWebAuthenticationSession.
    case cancelledByUser

    /// No network connectivity while talking to the provider.
    case network

    /// OAuth `state` mismatch or malformed callback URL. (Security-relevant.)
    case invalidCallback

    /// Provider rejected the credentials / code exchange.
    case unauthorized

    /// Stored session exists but could not be refreshed; user must log in again.
    case sessionExpired

    /// No stored session found during restore. Not really an "error" for the UI;
    /// it simply routes to the Login screen.
    case noStoredSession

    /// Keychain read/write failed.
    case secureStorage

    /// Anything unexpected. `debugDescription` is for logs only — never shown raw to the user.
    case unknown(debugDescription: String)
}

extension AuthError: LocalizedError {
    /// User-facing, safe messages. Raw HTTP bodies or provider payloads
    /// must never leak into these strings.
    var errorDescription: String? {
        switch self {
        case .cancelledByUser:
            return "Giriş işlemi iptal edildi."
        case .network:
            return "İnternet bağlantısı kurulamadı. Lütfen bağlantınızı kontrol edip tekrar deneyin."
        case .invalidCallback:
            return "Giriş yanıtı doğrulanamadı. Lütfen tekrar deneyin."
        case .unauthorized:
            return "Giriş başarısız oldu. Lütfen tekrar deneyin."
        case .sessionExpired:
            return "Oturumunuzun süresi doldu. Lütfen yeniden giriş yapın."
        case .noStoredSession:
            return nil // routing concern, not a user-visible error
        case .secureStorage:
            return "Oturum bilgileri güvenli depoya kaydedilemedi."
        case .unknown:
            return "Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin."
        }
    }
}
