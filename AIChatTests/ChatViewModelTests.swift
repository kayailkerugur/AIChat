//
//  ChatViewModelTests.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 6.07.2026.
//

import XCTest
@testable import AIChat

@MainActor
final class ChatViewModelTests: XCTestCase {

    private var store: InMemoryChatRepository!
    private var conversation: Conversation!

    override func setUp() async throws {
        try await super.setUp()
        store = InMemoryChatRepository()
        conversation = Conversation(
            title: SidebarViewModel.defaultTitle,
            providerID: "mock",
            modelID: "mock-fast"
        )
        try await store.create(conversation)
    }

    // MARK: - Helpers

    private func makeViewModel(
        ai behavior: MockAIProvider.Behavior = .init(chunkDelay: .zero)
    ) -> (ChatViewModel, MockAIProvider) {
        let provider = MockAIProvider(behavior: behavior)
        let viewModel = ChatViewModel(
            conversation: conversation,
            aiProvider: provider,
            messageRepository: store,
            conversationRepository: store
        )
        return (viewModel, provider)
    }

    /// Polls until `condition` is true or the timeout elapses.
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

    // MARK: - Happy path

    func test_sendDraft_appendsUserMessageAndStreamsAssistantResponse() async throws {
        let (viewModel, _) = makeViewModel()
        viewModel.draft = "Merhaba"

        viewModel.sendDraft()

        try await waitUntil("stream to finish") { !viewModel.isStreaming }

        XCTAssertEqual(viewModel.messages.count, 2)
        XCTAssertEqual(viewModel.messages[0].role, .user)
        XCTAssertEqual(viewModel.messages[0].content, "Merhaba")
        XCTAssertEqual(viewModel.messages[1].role, .assistant)
        XCTAssertEqual(viewModel.messages[1].status, .completed)
        XCTAssertFalse(viewModel.messages[1].content.isEmpty)
        XCTAssertTrue(viewModel.draft.isEmpty, "draft is cleared on send")
    }

    func test_completedResponse_isPersistedToRepository() async throws {
        let (viewModel, _) = makeViewModel()
        viewModel.draft = "Merhaba"
        viewModel.sendDraft()
        try await waitUntil("stream to finish") { !viewModel.isStreaming }

        // Persisted state must match what the UI shows.
        let persisted = try await store.messages(inConversation: conversation.id)
        let assistant = persisted.first { $0.role == .assistant }

        XCTAssertEqual(persisted.count, 2)
        XCTAssertEqual(assistant?.status, .completed)
        XCTAssertEqual(assistant?.content, viewModel.messages.last?.content)
    }

    // MARK: - Cancellation

    func test_stopStreaming_marksCancelledAndKeepsPartialContent() async throws {
        // Slow chunks so we can reliably cancel mid-stream.
        let (viewModel, _) = makeViewModel(
            ai: .init(chunkDelay: .milliseconds(50))
        )
        viewModel.draft = "Uzun bir yanıt istiyorum"
        viewModel.sendDraft()

        try await waitUntil("first delta to arrive") {
            viewModel.messages.last.map {
                $0.role == .assistant && !$0.content.isEmpty
            } ?? false
        }

        viewModel.stopStreaming()
        try await waitUntil("stream to stop") { !viewModel.isStreaming }

        let assistant = viewModel.messages.last
        XCTAssertEqual(assistant?.status, .cancelled)
        XCTAssertFalse(assistant?.content.isEmpty ?? true, "partial content kept")
        XCTAssertNil(assistant?.errorDescription, "user cancel is not an error")
    }

    // MARK: - Failure

    func test_midStreamFailure_marksFailedWithUserFacingMessage() async throws {
        let (viewModel, _) = makeViewModel(
            ai: .init(failure: .network, failAfterChunks: 3)
        )
        viewModel.draft = "Merhaba"
        viewModel.sendDraft()

        try await waitUntil("stream to finish") { !viewModel.isStreaming }

        let assistant = viewModel.messages.last
        XCTAssertEqual(assistant?.status, .failed)
        XCTAssertEqual(assistant?.errorDescription, AIError.network.errorDescription)
    }

    // MARK: - Concurrency guard (spec: overlapping requests are blocked)

    func test_whileStreaming_sendingIsBlocked() async throws {
        let (viewModel, _) = makeViewModel(
            ai: .init(chunkDelay: .milliseconds(50))
        )
        viewModel.draft = "İlk mesaj"
        viewModel.sendDraft()

        try await waitUntil("streaming to start") { viewModel.isStreaming }

        viewModel.draft = "Araya giren mesaj"
        XCTAssertFalse(viewModel.canSend, "canSend is false while streaming")

        viewModel.sendDraft() // guard must ignore this
        XCTAssertEqual(
            viewModel.messages.filter { $0.role == .user }.count, 1,
            "second send is ignored while streaming"
        )

        viewModel.stopStreaming()
        try await waitUntil("stream to stop") { !viewModel.isStreaming }
    }

    // MARK: - Regenerate

    func test_regenerate_replacesLastAssistantMessage() async throws {
        let (viewModel, _) = makeViewModel()
        viewModel.draft = "Merhaba"
        viewModel.sendDraft()
        try await waitUntil("first stream to finish") { !viewModel.isStreaming }
        let firstAssistantID = viewModel.messages.last?.id

        viewModel.regenerateLastResponse()
        try await waitUntil("second stream to finish") { !viewModel.isStreaming }

        XCTAssertEqual(viewModel.messages.count, 2, "still one user + one assistant")
        XCTAssertNotEqual(viewModel.messages.last?.id, firstAssistantID)
        XCTAssertEqual(viewModel.messages.last?.status, .completed)
    }

    // MARK: - Auto-title

    func test_firstMessage_setsConversationTitle() async throws {
        let (viewModel, _) = makeViewModel()
        viewModel.draft = "Swift Concurrency nedir?"
        viewModel.sendDraft()

        // Async polling — the title rename happens in a fire-and-forget
        // Task inside the view model, so we wait for it to land.
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            let title = try await store.conversations()
                .first { $0.id == conversation.id }?
                .title
            if title == "Swift Concurrency nedir?" { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("conversation title was not auto-set from the first message")
    }
}
