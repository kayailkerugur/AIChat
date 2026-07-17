import Foundation

/// Optional lifecycle hooks exposed to the host application.
@MainActor
public protocol AIChatSDKDelegate: AnyObject {
    func aiChatSDKDidBecomeReady()
    func aiChatSDKDidFail(with error: Error)
}

public extension AIChatSDKDelegate {
    func aiChatSDKDidBecomeReady() {}
    func aiChatSDKDidFail(with error: Error) {}
}

public enum AIChatSDKError: LocalizedError {
    case invalidLicense

    public var errorDescription: String? {
        switch self {
        case .invalidLicense:
            return "SDK lisansı geçersiz veya eksik."
        }
    }
}

/// License validation is injectable so online validation can be supplied by
/// the distributor without coupling the binary to a particular backend.
public protocol AIChatSDKLicenseValidating: Sendable {
    func validate(licenseKey: String?) async -> Bool
}

public struct AllowAllAIChatSDKLicenseValidator: AIChatSDKLicenseValidating {
    public init() {}
    public func validate(licenseKey: String?) async -> Bool { true }
}
