import Foundation
import XCTest
@testable import AIChatSDK

final class CoreDataProjectRepositoryTests: XCTestCase {
    func test_projectLifecyclePersistsAndOrdersProjects() async throws {
        let repository = CoreDataProjectRepository(
            persistence: PersistenceController(inMemory: true)
        )
        let older = AIChatProject(
            name: "Older",
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 10)
        )
        let newer = AIChatProject(
            name: "Newer",
            createdAt: Date(timeIntervalSince1970: 20),
            updatedAt: Date(timeIntervalSince1970: 20)
        )

        try await repository.create(older)
        try await repository.create(newer)
        let initialProjects = try await repository.projects()
        XCTAssertEqual(initialProjects.map(\.id), [newer.id, older.id])

        try await repository.rename(projectID: older.id, to: "Renamed")
        try await repository.touch(
            projectID: older.id,
            at: Date(timeIntervalSince1970: 30)
        )

        let renamedProject = try await repository.project(id: older.id)
        let reorderedProjects = try await repository.projects()
        XCTAssertEqual(renamedProject?.name, "Renamed")
        XCTAssertEqual(reorderedProjects.first?.id, older.id)

        try await repository.delete(projectID: newer.id)
        let deletedProject = try await repository.project(id: newer.id)
        XCTAssertNil(deletedProject)
    }
}
