import Foundation
import XCTest
@testable import AIChatSDK

@MainActor
final class InMemoryChatRepositoryTests: XCTestCase {
    func testConversationsAreSortedByUpdatedAtDescending() async throws {
        let repository = InMemoryChatRepository()
        let older = conversation(title: "Older", updatedAt: Date(timeIntervalSince1970: 1))
        let newer = conversation(title: "Newer", updatedAt: Date(timeIntervalSince1970: 2))

        try await repository.create(older)
        try await repository.create(newer)

        let conversations = try await repository.conversations()
        XCTAssertEqual(conversations.map(\.id), [newer.id, older.id])
    }

    func testRenameAndTouchUpdateConversation() async throws {
        let repository = InMemoryChatRepository()
        let item = conversation(title: "Original", updatedAt: Date(timeIntervalSince1970: 1))
        let touchedAt = Date(timeIntervalSince1970: 3)
        try await repository.create(item)

        try await repository.rename(conversationID: item.id, to: "Renamed")
        try await repository.touch(conversationID: item.id, at: touchedAt)

        let conversations = try await repository.conversations()
        let updated = try XCTUnwrap(conversations.first)
        XCTAssertEqual(updated.title, "Renamed")
        XCTAssertEqual(updated.updatedAt, touchedAt)
    }

    func testSearchMatchesTitleAndMessageContentCaseInsensitively() async throws {
        let repository = InMemoryChatRepository()
        let titleMatch = conversation(title: "Swift Concurrency")
        let messageMatch = conversation(title: "Other")
        try await repository.create(titleMatch)
        try await repository.create(messageMatch)
        try await repository.append(
            ChatMessage(role: .user, content: "PKCE implementation"),
            toConversation: messageMatch.id
        )

        let titleResults = try await repository.searchConversations(matching: "swift")
        let messageResults = try await repository.searchConversations(matching: "pkce")
        XCTAssertEqual(Set(titleResults.map(\.id)), [titleMatch.id])
        XCTAssertEqual(Set(messageResults.map(\.id)), [messageMatch.id])
    }

    func testEmptySearchReturnsAllConversations() async throws {
        let repository = InMemoryChatRepository()
        try await repository.create(conversation(title: "One"))
        try await repository.create(conversation(title: "Two"))

        let results = try await repository.searchConversations(matching: "  ")
        XCTAssertEqual(results.count, 2)
    }

    func testAppendUpdateAndDeleteMessage() async throws {
        let repository = InMemoryChatRepository()
        let item = conversation()
        var message = ChatMessage(role: .assistant, content: "Partial", status: .streaming)
        try await repository.create(item)
        try await repository.append(message, toConversation: item.id)

        message.content = "Complete"
        message.status = .completed
        try await repository.update(message, inConversation: item.id)

        let updatedMessages = try await repository.messages(inConversation: item.id)
        XCTAssertEqual(updatedMessages, [message])

        try await repository.deleteMessage(id: message.id, inConversation: item.id)
        let remainingMessages = try await repository.messages(inConversation: item.id)
        XCTAssertTrue(remainingMessages.isEmpty)
    }

    func testMessagesPreserveAppendOrder() async throws {
        let repository = InMemoryChatRepository()
        let item = conversation()
        let first = ChatMessage(role: .user, content: "First")
        let second = ChatMessage(role: .assistant, content: "Second")
        try await repository.create(item)
        try await repository.append(first, toConversation: item.id)
        try await repository.append(second, toConversation: item.id)

        let messages = try await repository.messages(inConversation: item.id)
        XCTAssertEqual(messages.map(\.id), [first.id, second.id])
    }

    func testDeletingConversationCascadesMessages() async throws {
        let repository = InMemoryChatRepository()
        let item = conversation()
        try await repository.create(item)
        try await repository.append(
            ChatMessage(role: .user, content: "Message"),
            toConversation: item.id
        )

        try await repository.delete(conversationID: item.id)

        let conversations = try await repository.conversations()
        let messages = try await repository.messages(inConversation: item.id)
        XCTAssertTrue(conversations.isEmpty)
        XCTAssertTrue(messages.isEmpty)
    }

    func testConversationsCanBeFilteredAndMovedBetweenProjects() async throws {
        let repository = InMemoryChatRepository()
        let firstProjectID = UUID()
        let secondProjectID = UUID()
        var assigned = conversation(title: "Assigned")
        assigned.projectID = firstProjectID
        let unassigned = conversation(title: "Unassigned")
        try await repository.create(assigned)
        try await repository.create(unassigned)

        let firstProject = try await repository.conversations(
            inProject: firstProjectID
        )
        let withoutProject = try await repository.conversations(
            inProject: nil
        )
        XCTAssertEqual(firstProject.map(\.id), [assigned.id])
        XCTAssertEqual(withoutProject.map(\.id), [unassigned.id])

        try await repository.move(
            conversationID: assigned.id,
            toProject: secondProjectID
        )
        let moved = try await repository.conversations(
            inProject: secondProjectID
        )
        XCTAssertEqual(moved.first?.projectID, secondProjectID)
    }

    private func conversation(
        title: String = "Conversation",
        updatedAt: Date = Date(timeIntervalSince1970: 1)
    ) -> Conversation {
        Conversation(
            title: title,
            createdAt: updatedAt,
            updatedAt: updatedAt,
            providerID: "provider",
            modelID: "model"
        )
    }
}
