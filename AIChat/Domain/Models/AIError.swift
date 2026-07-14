//
//  AIError.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 3.07.2026.
//
//  Domain/Models
//
//  Common error model for the AI layer. Providers map HTTP status codes,
//  SSE parse failures and SDK errors into these cases. Same philosophy
//  as AuthError: raw response bodies never reach the user or the logs.
//

import Foundation

enum AIError: Error, Equatable {
    /// No connectivity / request could not reach the provider.
    case network
    /// Missing or invalid API credential (401/403).
    case unauthorized
    /// Provider-side rate limit (429). UI may suggest retrying later.
    case rateLimited
    /// Provider quota/billing is exhausted or unavailable.
    case quotaExceeded
    /// Requested model is unknown or not available to this account.
    case modelUnavailable
    /// The stream ended unexpectedly or a chunk could not be parsed.
    case malformedResponse
    /// Provider returned a safe, user-actionable error message.
    case providerRejected(message: String)
    /// The user cancelled the request. Not shown as an error in UI.
    case cancelled
    /// Anything else. debugDescription is for logs only.
    case unknown(debugDescription: String)
}

extension AIError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .network:
            return "Bağlantı kurulamadı. İnternet bağlantınızı kontrol edip tekrar deneyin."
        case .unauthorized:
            return "API anahtarı geçersiz veya eksik. Ayarlardan sağlayıcı API anahtarını kontrol edin."
        case .rateLimited:
            return "Çok fazla istek gönderildi. Kısa bir süre sonra tekrar deneyin."
        case .quotaExceeded:
            return "API kredisi veya kota yetersiz. Sağlayıcı hesabınızın kullanım ve faturalandırma ayarlarını kontrol edin."
        case .modelUnavailable:
            return "Model bulunamadı veya hesabınız için kullanılamıyor. Ayarlardan farklı bir model seçin."
        case .malformedResponse:
            return "Yanıt işlenirken bir sorun oluştu. Lütfen tekrar deneyin."
        case .providerRejected(let message):
            return message
        case .cancelled:
            return nil // user's own action — routing/status concern, not an error banner
        case .unknown:
            return "Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin."
        }
    }
}
