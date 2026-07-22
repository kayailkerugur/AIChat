import Foundation

@MainActor
public protocol AIProvider: AnyObject, Sendable {
    var id: String { get }
    var supportedModels: [AIModel] { get }
    var supportsImages: Bool { get }

    @discardableResult
    func refreshModels() async throws -> [AIModel]

    func stream(request: ChatRequest) -> AsyncThrowingStream<AIStreamEvent, Error>
    func cancelCurrentRequest()
}
