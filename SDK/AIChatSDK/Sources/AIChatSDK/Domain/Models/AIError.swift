import Foundation

public enum AIError: Error, Equatable, Sendable {
    case network
    case unauthorized
    case rateLimited
    case quotaExceeded
    case modelUnavailable
    case malformedResponse
    case providerRejected(message: String)
    case cancelled
    case unknown(debugDescription: String)
}

extension AIError: LocalizedError {
    public var errorDescription: String? {
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
            return nil
        case .unknown:
            return "Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin."
        }
    }
}
