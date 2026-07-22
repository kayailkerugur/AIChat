import Foundation

public struct AIModel: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let displayName: String
    public let providerID: String

    public init(id: String, displayName: String, providerID: String) {
        self.id = id
        self.displayName = displayName
        self.providerID = providerID
    }
}
