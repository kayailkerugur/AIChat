import Foundation
import XCTest
@testable import AIChatSDK

final class DomainModelTests: XCTestCase {
    func testChatMessageInitializationAndEquality() {
        let id = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let attachment = ChatAttachment(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            fileName: "notes.txt",
            mimeType: "text/plain",
            kind: .document,
            data: Data("hello".utf8),
            extractedText: "hello"
        )

        let message = ChatMessage(
            id: id,
            role: .user,
            content: "Hello",
            attachments: [attachment],
            createdAt: date,
            status: .completed
        )

        XCTAssertEqual(message, ChatMessage(
            id: id,
            role: .user,
            content: "Hello",
            attachments: [attachment],
            createdAt: date,
            status: .completed
        ))
        XCTAssertTrue(message.status.isTerminal)
    }

    func testConversationInitializationAndEquality() {
        let id = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let date = Date(timeIntervalSince1970: 1_700_000_001)
        let conversation = Conversation(
            id: id,
            title: "Test",
            createdAt: date,
            updatedAt: date,
            providerID: "provider",
            modelID: "model"
        )

        XCTAssertEqual(conversation.id, id)
        XCTAssertEqual(conversation.title, "Test")
        XCTAssertEqual(conversation.providerID, "provider")
        XCTAssertEqual(conversation.modelID, "model")
    }

    func testProviderConfigCodableRoundTrip() throws {
        let config = ProviderConfig(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            name: "Local",
            baseURL: URL(string: "http://localhost:11434/v1")!,
            requiresAPIKey: false,
            supportsImages: true,
            models: [.init(id: "model-a", displayName: "Model A")]
        )

        let decoded = try JSONDecoder().decode(
            ProviderConfig.self,
            from: JSONEncoder().encode(config)
        )

        XCTAssertEqual(decoded, config)
        XCTAssertEqual(decoded.asAIModels.first?.providerID, config.providerID)
    }

    func testProviderConfigDecodesLegacyDefaults() throws {
        let json = #"""
        {
            "id":"55555555-5555-5555-5555-555555555555",
            "name":"Legacy",
            "baseURL":"https://example.com/v1",
            "requiresAPIKey":true
        }
        """#.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(ProviderConfig.self, from: json)

        XCTAssertFalse(decoded.supportsImages)
        XCTAssertTrue(decoded.models.isEmpty)
        XCTAssertNil(decoded.modelsFetchedAt)
    }

    func testEnumCodableRawValues() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        XCTAssertEqual(try decoder.decode(MessageRole.self, from: encoder.encode(MessageRole.assistant)), .assistant)
        XCTAssertEqual(try decoder.decode(MessageStatus.self, from: encoder.encode(MessageStatus.streaming)), .streaming)
        XCTAssertEqual(try decoder.decode(ChatAttachmentKind.self, from: encoder.encode(ChatAttachmentKind.image)), .image)
    }
}
