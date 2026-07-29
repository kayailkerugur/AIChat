import Foundation

/// A developer workspace that owns one repository and can contain multiple
/// conversations. Repository access credentials/bookmarks remain host-owned
/// and are keyed by this stable identifier.
public struct AIChatProject: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
