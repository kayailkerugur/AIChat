import Foundation

public enum ChatAttachmentKind: String, Codable, Equatable, Sendable {
    case image
    case document
}

public struct ChatAttachment: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let fileName: String
    public let mimeType: String
    public let kind: ChatAttachmentKind
    public let data: Data
    public let extractedText: String?

    public init(
        id: UUID = UUID(),
        fileName: String,
        mimeType: String,
        kind: ChatAttachmentKind,
        data: Data,
        extractedText: String? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.mimeType = mimeType
        self.kind = kind
        self.data = data
        self.extractedText = extractedText
    }
}
