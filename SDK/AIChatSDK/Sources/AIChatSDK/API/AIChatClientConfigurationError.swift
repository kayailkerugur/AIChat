import Foundation

public enum AIChatClientConfigurationError: LocalizedError, Equatable, Sendable {
    case codeModeRequired
    case repositoryProviderRequired
    case projectRepositoryRequired

    public var errorDescription: String? {
        switch self {
        case .codeModeRequired:
            return "Repository özellikleri yalnızca kod modunda kullanılabilir."
        case .repositoryProviderRequired:
            return "Kod modu için bir repository provider gerekli."
        case .projectRepositoryRequired:
            return "Proje işlemleri için bir project repository gerekli."
        }
    }
}
