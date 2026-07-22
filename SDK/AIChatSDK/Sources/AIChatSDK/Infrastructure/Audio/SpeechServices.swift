@MainActor
public protocol SpeechRecognizer: AnyObject, Sendable {
    func requestAuthorization() async -> Bool
    func startRecording() throws
    func stopAndRecognize() async throws -> String
}

@MainActor
public protocol SpeechSynthesizer: AnyObject, Sendable {
    var isPaused: Bool { get }

    func speak(_ text: String) async
    func stop()
    func pause()
    func resumeSpeaking()
}
