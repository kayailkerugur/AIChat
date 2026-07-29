import Foundation

public struct Conversation: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public let createdAt: Date
    public var updatedAt: Date
    public var providerID: String
    public var modelID: String
    public var projectID: UUID?

    public init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        providerID: String,
        modelID: String,
        projectID: UUID? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.providerID = providerID
        self.modelID = modelID
        self.projectID = projectID
    }
}
