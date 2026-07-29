import CoreData
import Foundation

/// Persistent project store backed by the SDK's existing Core Data container.
///
/// Repository bookmarks remain host-owned and are associated using the
/// project's stable identifier.
public final class CoreDataProjectRepository:
    ProjectRepository,
    @unchecked Sendable
{
    private let persistence: PersistenceController
    private let logger = SDKLogger.persistence

    public init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    public func projects() async throws -> [AIChatProject] {
        let context = persistence.newBackgroundContext()
        return try await context.perform {
            let request = CDProject.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "updatedAt", ascending: false),
                NSSortDescriptor(
                    key: "name",
                    ascending: true,
                    selector: #selector(NSString.localizedStandardCompare)
                )
            ]
            return try context.fetch(request).map { $0.toDomain() }
        }
    }

    public func project(id: UUID) async throws -> AIChatProject? {
        let context = persistence.newBackgroundContext()
        return try await context.perform {
            try self.fetchProject(id, in: context)?.toDomain()
        }
    }

    public func create(_ project: AIChatProject) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            let entity = CDProject(context: context)
            entity.apply(project)
            try self.save(context, action: "create project")
        }
    }

    public func rename(projectID: UUID, to name: String) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            guard let entity = try self.fetchProject(projectID, in: context)
            else { return }
            entity.name = name
            try self.save(context, action: "rename project")
        }
    }

    public func touch(projectID: UUID, at date: Date) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            guard let entity = try self.fetchProject(projectID, in: context)
            else { return }
            entity.updatedAt = date
            try self.save(context, action: "touch project")
        }
    }

    public func delete(projectID: UUID) async throws {
        let context = persistence.newBackgroundContext()
        try await context.perform {
            guard let entity = try self.fetchProject(projectID, in: context)
            else { return }
            context.delete(entity)
            try self.save(context, action: "delete project")
        }
    }

    private func fetchProject(
        _ id: UUID,
        in context: NSManagedObjectContext
    ) throws -> CDProject? {
        let request = CDProject.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private func save(
        _ context: NSManagedObjectContext,
        action: String
    ) throws {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            logger.error("\(action) failed: \(error.localizedDescription)")
            throw error
        }
    }
}
