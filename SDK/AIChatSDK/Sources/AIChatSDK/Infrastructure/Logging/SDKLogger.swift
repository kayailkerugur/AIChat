import os

enum SDKLogger {
    private static let subsystem = "com.kayailker.AIChatSDK"

    static let persistence = Logger(
        subsystem: subsystem,
        category: "persistence"
    )
    static let provider = Logger(
        subsystem: subsystem,
        category: "ai-provider"
    )
    static let providerConfiguration = Logger(
        subsystem: subsystem,
        category: "provider-configuration"
    )
    static let secureStorage = Logger(
        subsystem: subsystem,
        category: "secure-storage"
    )
}
