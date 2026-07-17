import SwiftUI

/// Public SwiftUI entry point. The host retains ownership of its `@main` App.
public struct AIChatSDKView: View {
    private let configuration: AIChatSDKConfiguration
    private let delegate: (any AIChatSDKDelegate)?
    private let licenseValidator: any AIChatSDKLicenseValidating

    @State private var validationState: ValidationState = .checking

    public init(
        configuration: AIChatSDKConfiguration = .init(),
        delegate: (any AIChatSDKDelegate)? = nil,
        licenseValidator: any AIChatSDKLicenseValidating = AllowAllAIChatSDKLicenseValidator()
    ) {
        self.configuration = configuration
        self.delegate = delegate
        self.licenseValidator = licenseValidator
    }

    public var body: some View {
        Group {
            switch validationState {
            case .checking:
                ProgressView("SDK hazırlanıyor…")
            case .ready:
                RootView(dependencies: .makeDefault(configuration: configuration))
            case .failed(let message):
                ContentUnavailableView(
                    "SDK başlatılamadı",
                    systemImage: "exclamationmark.triangle",
                    description: Text(message)
                )
            }
        }
        .tint(configuration.branding.accentColor)
        .environment(\.aiChatSDKConfiguration, configuration)
        .task { await validateLicense() }
    }

    private func validateLicense() async {
        guard case .checking = validationState else { return }
        if await licenseValidator.validate(licenseKey: configuration.licenseKey) {
            validationState = .ready
            delegate?.aiChatSDKDidBecomeReady()
        } else {
            let error = AIChatSDKError.invalidLicense
            validationState = .failed(error.localizedDescription)
            delegate?.aiChatSDKDidFail(with: error)
        }
    }
}

private enum ValidationState {
    case checking
    case ready
    case failed(String)
}
