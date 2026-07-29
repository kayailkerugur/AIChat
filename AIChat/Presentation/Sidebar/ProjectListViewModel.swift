import AIChatSDK
import Foundation
import Observation

@MainActor
@Observable
final class ProjectListViewModel {
    private(set) var projects: [AIChatProject] = []
    private(set) var errorMessage: String?
    var selectedProjectID: UUID?

    var selectedProject: AIChatProject? {
        guard let selectedProjectID else { return nil }
        return projects.first { $0.id == selectedProjectID }
    }

    private let repository: any ProjectRepository

    init(repository: any ProjectRepository) {
        self.repository = repository
    }

    func refresh() async {
        do {
            projects = try await repository.projects()
            if let selectedProjectID,
               !projects.contains(where: { $0.id == selectedProjectID }) {
                self.selectedProjectID = nil
            }
            errorMessage = nil
        } catch {
            errorMessage = "Projeler yüklenemedi."
        }
    }

    func createProject(name: String) async -> AIChatProject? {
        let trimmedName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedName.isEmpty else { return nil }

        let project = AIChatProject(name: trimmedName)
        do {
            try await repository.create(project)
            await refresh()
            selectedProjectID = project.id
            return project
        } catch {
            errorMessage = "Proje oluşturulamadı."
            return nil
        }
    }

    func rename(projectID: UUID, to name: String) async {
        let trimmedName = name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedName.isEmpty else { return }
        do {
            try await repository.rename(
                projectID: projectID,
                to: trimmedName
            )
            await refresh()
        } catch {
            errorMessage = "Proje yeniden adlandırılamadı."
        }
    }

    func delete(projectID: UUID) async -> Bool {
        do {
            try await repository.delete(projectID: projectID)
            if selectedProjectID == projectID {
                selectedProjectID = nil
            }
            await refresh()
            return true
        } catch {
            errorMessage = "Proje silinemedi."
            return false
        }
    }

    func reportDeletionFailure() {
        errorMessage =
            "Sohbetler korunamadığı için proje silme işlemi iptal edildi."
    }

    func dismissError() {
        errorMessage = nil
    }
}
