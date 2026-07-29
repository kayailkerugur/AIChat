import Foundation
import XCTest
@testable import AIChatSDK

final class InMemoryProjectRepositoryTests: XCTestCase {
    func test_projectLifecycleAndOrdering() async throws {
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
        let repository = InMemoryProjectRepository()

        try await repository.create(older)
        try await repository.create(newer)

        let initialProjectIDs = try await repository.projects().map(\.id)
        XCTAssertEqual(initialProjectIDs, [newer.id, older.id])

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

    func test_projectInitializationAndEquality() {
        let id = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let project = AIChatProject(
            id: id,
            name: "AIChat",
            createdAt: date,
            updatedAt: date
        )

        XCTAssertEqual(
            project,
            AIChatProject(
                id: id,
                name: "AIChat",
                createdAt: date,
                updatedAt: date
            )
        )
    }
}
