import Foundation
import XCTest
@testable import AIChatSDK

@MainActor
final class VoiceCallViewModelTests: XCTestCase {
    func testDeniedAuthorizationMovesToFailedState() async throws {
        let recognizer = MockSpeechRecognizer(
            authorizationGranted: false,
            transcript: ""
        )
        let synthesizer = MockSpeechSynthesizer()
        let viewModel = try await makeViewModel(
            recognizer: recognizer,
            synthesizer: synthesizer
        )

        viewModel.startRecording()

        try await waitUntil("authorization failure") {
            if case .failed = viewModel.status { return true }
            return false
        }
        XCTAssertEqual(
            viewModel.status,
            .failed("Mikrofon veya konuşma tanıma izni verilmedi.")
        )
        XCTAssertFalse(viewModel.isRecording)
        XCTAssertFalse(recognizer.didStartRecording)
    }

    func testTranscriptUsesChatPipelineAndSpeaksReply() async throws {
        let recognizer = MockSpeechRecognizer(
            authorizationGranted: true,
            transcript: "Merhaba"
        )
        let synthesizer = MockSpeechSynthesizer()
        let viewModel = try await makeViewModel(
            recognizer: recognizer,
            synthesizer: synthesizer
        )

        viewModel.startRecording()
        try await waitUntil("recording to start") { viewModel.isRecording }
        viewModel.stopRecordingAndSend()

        try await waitUntil("reply to be spoken") {
            !synthesizer.spokenTexts.isEmpty
        }

        XCTAssertEqual(viewModel.lastUserTranscript, "Merhaba")
        XCTAssertFalse(viewModel.lastAssistantReply.isEmpty)
        XCTAssertEqual(synthesizer.spokenTexts, [viewModel.lastAssistantReply])
        XCTAssertEqual(viewModel.status, .idle)
    }

    private func makeViewModel(
        recognizer: any SpeechRecognizer,
        synthesizer: any SpeechSynthesizer
    ) async throws -> VoiceCallViewModel {
        let store = InMemoryChatRepository()
        let conversation = Conversation(
            title: "Yeni Sohbet",
            providerID: "mock",
            modelID: "mock-fast"
        )
        try await store.create(conversation)
        let chatViewModel = ChatViewModel(
            conversation: conversation,
            aiProvider: MockAIProvider(
                behavior: .init(chunkDelay: .zero)
            ),
            messageRepository: store,
            conversationRepository: store
        )
        return VoiceCallViewModel(
            chatViewModel: chatViewModel,
            speechRecognizer: recognizer,
            speechSynthesizer: synthesizer
        )
    }

    private func waitUntil(
        timeout: TimeInterval = 2,
        _ description: String,
        _ condition: @escaping () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline {
                XCTFail("Timed out waiting for: \(description)")
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}

@MainActor
private final class MockSpeechRecognizer: SpeechRecognizer {
    let authorizationGranted: Bool
    let transcript: String
    private(set) var didStartRecording = false

    init(authorizationGranted: Bool, transcript: String) {
        self.authorizationGranted = authorizationGranted
        self.transcript = transcript
    }

    func requestAuthorization() async -> Bool {
        authorizationGranted
    }

    func startRecording() throws {
        didStartRecording = true
    }

    func stopAndRecognize() async throws -> String {
        transcript
    }
}

@MainActor
private final class MockSpeechSynthesizer: SpeechSynthesizer {
    private(set) var spokenTexts: [String] = []
    private(set) var isPaused = false

    func speak(_ text: String) async {
        spokenTexts.append(text)
    }

    func stop() {
        isPaused = false
    }

    func pause() {
        isPaused = true
    }

    func resumeSpeaking() {
        isPaused = false
    }
}
