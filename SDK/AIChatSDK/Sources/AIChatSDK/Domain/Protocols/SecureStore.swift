import Foundation

public enum SecureStoreError: Error, Equatable, Sendable {
    case unhandled(status: Int32)
    case corruptedData
}

@MainActor
public protocol SecureStore: AnyObject, Sendable {
    func read(key: String) throws -> String?
    func save(_ value: String, forKey key: String) throws
    func delete(key: String) throws
}
