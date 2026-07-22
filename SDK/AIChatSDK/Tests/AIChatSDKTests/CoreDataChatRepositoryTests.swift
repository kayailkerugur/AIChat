//
//  CoreDataChatRepositoryTests.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 6.07.2026.
//

import XCTest
import CoreData
@testable import AIChatSDK

final class CoreDataChatRepositoryTests: XCTestCase {

    private var persistence: PersistenceController!
    private var repository: CoreDataChatRepository!
    private var attachmentDirectory: URL!

    override func setUp() {
        super.setUp()
        persistence = PersistenceController(inMemory: true)
        attachmentDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        repository = CoreDataChatRepository(
            persistence: persistence,
            attachmentFileStore: AttachmentFileStore(rootDirectory: attachmentDirectory)
        )
    }

    override func tearDown() {
        repository = nil
        persistence = nil
        if let attachmentDirectory {
            try? FileManager.default.removeItem(at: attachmentDirectory)
        }
        attachmentDirectory = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeConversation(
        title: String = "Test Sohbeti",
        updatedAt: Date = Date()
    ) -> Conversation {
        Conversation(
            title: title,
            updatedAt: updatedAt,
            providerID: "mock",
            modelID: "mock-fast"
        )
    }

    /// Counts CDMessage rows directly in the store — used to verify
    /// cascade delete actually removed rows, not just the relationship.
    private func totalMessageRowCount() throws -> Int {
        let context = persistence.container.viewContext
        return try context.count(for: CDMessage.fetchRequest())
    }

    // MARK: - Conversation CRUD

    func test_createAndFetch_roundTripsAllFields() async throws {
        let conversation = makeConversation(title: "Alanlar")

        try await repository.create(conversation)
        let fetched = try await repository.conversations()

        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched[0].id, conversation.id)
        XCTAssertEqual(fetched[0].title, "Alanlar")
        XCTAssertEqual(fetched[0].providerID, "mock")
        XCTAssertEqual(fetched[0].modelID, "mock-fast")
    }

    func test_rename_updatesTitle() async throws {
        let conversation = makeConversation(title: "Eski Başlık")
        try await repository.create(conversation)

        try await repository.rename(conversationID: conversation.id, to: "Yeni Başlık")

        let fetched = try await repository.conversations()
        XCTAssertEqual(fetched[0].title, "Yeni Başlık")
    }

    func test_conversations_areSortedByUpdatedAtDescending() async throws {
        let old = makeConversation(title: "Eski", updatedAt: Date(timeIntervalSinceNow: -100))
        let new = makeConversation(title: "Yeni", updatedAt: Date())
        try await repository.create(old)
        try await repository.create(new)

        let fetched = try await repository.conversations()

        XCTAssertEqual(fetched.map(\.title), ["Yeni", "Eski"])
    }

    func test_touch_movesConversationToTop() async throws {
        let first = makeConversation(title: "Birinci", updatedAt: Date(timeIntervalSinceNow: -100))
        let second = makeConversation(title: "İkinci", updatedAt: Date(timeIntervalSinceNow: -50))
        try await repository.create(first)
        try await repository.create(second)

        try await repository.touch(conversationID: first.id, at: Date())

        let fetched = try await repository.conversations()
        XCTAssertEqual(fetched.map(\.title), ["Birinci", "İkinci"])
    }

    // MARK: - Cascade delete (acceptance criterion 10)

    func test_deleteConversation_cascadesToMessages() async throws {
        let conversation = makeConversation()
        try await repository.create(conversation)
        try await repository.append(
            ChatMessage(role: .user, content: "Merhaba"),
            toConversation: conversation.id
        )
        try await repository.append(
            ChatMessage(role: .assistant, content: "Selam!"),
            toConversation: conversation.id
        )
        XCTAssertEqual(try totalMessageRowCount(), 2)

        try await repository.delete(conversationID: conversation.id)

        let conversations = try await repository.conversations()
        XCTAssertTrue(conversations.isEmpty)
        // Rows are gone from the store, not merely unlinked.
        XCTAssertEqual(try totalMessageRowCount(), 0)
    }

    // MARK: - Search

    func test_search_matchesTitleCaseInsensitively() async throws {
        try await repository.create(makeConversation(title: "Swift Yardım"))
        try await repository.create(makeConversation(title: "Alışveriş Listesi"))

        let results = try await repository.searchConversations(matching: "swift")

        XCTAssertEqual(results.map(\.title), ["Swift Yardım"])
    }

    func test_search_matchesMessageContent() async throws {
        let match = makeConversation(title: "Sohbet A")
        let other = makeConversation(title: "Sohbet B")
        try await repository.create(match)
        try await repository.create(other)
        try await repository.append(
            ChatMessage(role: .user, content: "PKCE akışını anlatır mısın?"),
            toConversation: match.id
        )

        let results = try await repository.searchConversations(matching: "pkce")

        XCTAssertEqual(results.map(\.id), [match.id])
    }

    func test_search_emptyQuery_returnsAll() async throws {
        try await repository.create(makeConversation(title: "Bir"))
        try await repository.create(makeConversation(title: "İki"))

        let results = try await repository.searchConversations(matching: "   ")

        XCTAssertEqual(results.count, 2)
    }

    // MARK: - Messages

    func test_messages_areSortedByCreatedAtAscending() async throws {
        let conversation = makeConversation()
        try await repository.create(conversation)
        try await repository.append(
            ChatMessage(role: .user, content: "İlk", createdAt: Date(timeIntervalSinceNow: -10)),
            toConversation: conversation.id
        )
        try await repository.append(
            ChatMessage(role: .assistant, content: "İkinci", createdAt: Date()),
            toConversation: conversation.id
        )

        let messages = try await repository.messages(inConversation: conversation.id)

        XCTAssertEqual(messages.map(\.content), ["İlk", "İkinci"])
    }

    func test_updateMessage_persistsContentAndStatus() async throws {
        let conversation = makeConversation()
        try await repository.create(conversation)
        var message = ChatMessage(role: .assistant, content: "", status: .streaming)
        try await repository.append(message, toConversation: conversation.id)

        message.content = "Tamamlanan yanıt"
        message.status = .completed
        try await repository.update(message, inConversation: conversation.id)

        let fetched = try await repository.messages(inConversation: conversation.id)
        XCTAssertEqual(fetched[0].content, "Tamamlanan yanıt")
        XCTAssertEqual(fetched[0].status, .completed)
    }

    func test_appendMessage_persistsAttachments() async throws {
        let conversation = makeConversation()
        try await repository.create(conversation)
        let attachment = ChatAttachment(
            fileName: "notlar.txt",
            mimeType: "text/plain",
            kind: .document,
            data: Data("Merhaba".utf8),
            extractedText: "Merhaba"
        )
        let message = ChatMessage(
            role: .user,
            content: "Bunu özetle",
            attachments: [attachment]
        )

        try await repository.append(message, toConversation: conversation.id)

        let fetched = try await repository.messages(inConversation: conversation.id)
        XCTAssertEqual(fetched[0].attachments.count, 1)
        XCTAssertEqual(fetched[0].attachments[0].fileName, "notlar.txt")
        XCTAssertEqual(fetched[0].attachments[0].mimeType, "text/plain")
        XCTAssertEqual(fetched[0].attachments[0].kind, .document)
        XCTAssertEqual(fetched[0].attachments[0].data, Data("Merhaba".utf8))
        XCTAssertEqual(fetched[0].attachments[0].extractedText, "Merhaba")
    }

    func test_deleteMessage_removesOnlyThatMessage() async throws {
        let conversation = makeConversation()
        try await repository.create(conversation)
        let keep = ChatMessage(role: .user, content: "Kalacak")
        let remove = ChatMessage(role: .assistant, content: "Silinecek")
        try await repository.append(keep, toConversation: conversation.id)
        try await repository.append(remove, toConversation: conversation.id)

        try await repository.deleteMessage(id: remove.id, inConversation: conversation.id)

        let messages = try await repository.messages(inConversation: conversation.id)
        XCTAssertEqual(messages.map(\.id), [keep.id])
    }

    // MARK: - Launch repair (spec §3.3)

    func test_repairInterruptedStreams_movesNonTerminalRowsToFailed() async throws {
        let conversation = makeConversation()
        try await repository.create(conversation)
        try await repository.append(
            ChatMessage(role: .assistant, content: "Yarım ka", status: .streaming),
            toConversation: conversation.id
        )
        try await repository.append(
            ChatMessage(role: .user, content: "Tamam", status: .completed),
            toConversation: conversation.id
        )

        try await repository.repairInterruptedStreams()

        let messages = try await repository.messages(inConversation: conversation.id)
        let repaired = messages.first { $0.role == .assistant }
        let untouched = messages.first { $0.role == .user }

        XCTAssertEqual(repaired?.status, .failed)
        XCTAssertNotNil(repaired?.errorDescription)
        XCTAssertEqual(repaired?.content, "Yarım ka") // partial content kept
        XCTAssertEqual(untouched?.status, .completed) // terminal rows untouched
    }
}
