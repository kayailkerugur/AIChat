import Foundation

/// Deterministic project store for previews, integration tests and hosts that
/// do not require persistence.
public actor InMemoryProjectRepository: ProjectRepository {
    private var projectsByID: [UUID: AIChatProject]

    public init(projects: [AIChatProject] = []) {
        projectsByID = Dictionary(
            uniqueKeysWithValues: projects.map { ($0.id, $0) }
        )
    }

    public func projects() async throws -> [AIChatProject] {
        projectsByID.values.sorted { lhs, rhs in
            if lhs.updatedAt == rhs.updatedAt {
                return lhs.name.localizedStandardCompare(rhs.name)
                    == .orderedAscending
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    public func project(id: UUID) async throws -> AIChatProject? {
        projectsByID[id]
    }

    public func create(_ project: AIChatProject) async throws {
        projectsByID[project.id] = project
    }

    public func rename(projectID: UUID, to name: String) async throws {
        projectsByID[projectID]?.name = name
    }

    public func touch(projectID: UUID, at date: Date) async throws {
        projectsByID[projectID]?.updatedAt = date
    }

    public func delete(projectID: UUID) async throws {
        projectsByID.removeValue(forKey: projectID)
    }
}
