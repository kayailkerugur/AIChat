import AIChatSDK
import Foundation

struct AppSDKConfiguration {
    var mode: AIChatMode
    var repositoryURL: URL?
    var repositoryBookmarkData: Data?
    var repositoryError: RepositoryError?
    var codeContextCharacterLimit: Int
    var codeFileByteLimit: Int

    init(
        mode: AIChatMode = .standard,
        repositoryURL: URL? = nil,
        repositoryBookmarkData: Data? = nil,
        repositoryError: RepositoryError? = nil,
        codeContextCharacterLimit: Int = 40_000,
        codeFileByteLimit: Int = 200_000
    ) {
        self.mode = mode
        self.repositoryURL = repositoryURL
        self.repositoryBookmarkData = repositoryBookmarkData
        self.repositoryError = repositoryError
        self.codeContextCharacterLimit = codeContextCharacterLimit
        self.codeFileByteLimit = codeFileByteLimit
    }

    /// The single compile-time selection point for the running application.
    nonisolated static let current = AppSDKConfiguration(
        mode: .code,
        repositoryURL: nil
    )

    var sdkConfiguration: AIChatConfiguration {
        AIChatConfiguration(
            mode: mode,
            codeContextCharacterLimit: codeContextCharacterLimit,
            codeFileByteLimit: codeFileByteLimit
        )
    }

}
