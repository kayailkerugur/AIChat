/// Stable public-facing name for an AI provider's configuration.
///
/// `ProviderConfig` remains available for source compatibility while the SDK
/// migrates toward its distribution API without duplicating the underlying
/// model or its persisted Codable representation.
public typealias ProviderConfiguration = ProviderConfig

/// Stable public-facing name for errors produced by AI chat operations.
///
/// This alias preserves the existing `AIError` cases and avoids introducing a
/// second error model that callers would need to translate.
public typealias AIChatError = AIError
