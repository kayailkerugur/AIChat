import Foundation

/// Persistence boundary for project workspaces.
///
/// Repository bookmarks and filesystem access are deliberately excluded:
/// those remain behind `RepositoryProvider`.
public protocol ProjectRepository: Sendable {
    func projects() async throws -> [AIChatProject]
    func project(id: UUID) async throws -> AIChatProject?
    func create(_ project: AIChatProject) async throws
    func rename(projectID: UUID, to name: String) async throws
    func touch(projectID: UUID, at date: Date) async throws
    func delete(projectID: UUID) async throws
}
