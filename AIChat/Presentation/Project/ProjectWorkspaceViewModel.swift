import AIChatSDK
import Foundation
import Observation

struct ProjectWorkspaceMetadata: Codable, Equatable {
    var summary = ""
}

@MainActor
protocol ProjectWorkspaceMetadataStoring {
    func metadata(for projectID: UUID) -> ProjectWorkspaceMetadata
    func save(_ metadata: ProjectWorkspaceMetadata, for projectID: UUID)
}

@MainActor
final class UserDefaultsProjectWorkspaceMetadataStore:
    ProjectWorkspaceMetadataStoring
{
    private let defaults: UserDefaults
    private let keyPrefix = "project-workspace-metadata."

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func metadata(for projectID: UUID) -> ProjectWorkspaceMetadata {
        guard let data = defaults.data(
            forKey: keyPrefix + projectID.uuidString
        ) else {
            return ProjectWorkspaceMetadata()
        }
        return (try? JSONDecoder().decode(
            ProjectWorkspaceMetadata.self,
            from: data
        )) ?? ProjectWorkspaceMetadata()
    }

    func save(_ metadata: ProjectWorkspaceMetadata, for projectID: UUID) {
        guard let data = try? JSONEncoder().encode(metadata) else { return }
        defaults.set(data, forKey: keyPrefix + projectID.uuidString)
    }
}

@MainActor
@Observable
final class ProjectWorkspaceViewModel {
    var summary: String
    private(set) var conversations: [Conversation] = []
    private(set) var errorMessage: String?

    private let projectID: UUID
    private let conversationRepository: any ConversationRepository
    private let metadataStore: any ProjectWorkspaceMetadataStoring

    init(
        projectID: UUID,
        conversationRepository: any ConversationRepository,
        metadataStore: (any ProjectWorkspaceMetadataStoring)? = nil
    ) {
        self.projectID = projectID
        self.conversationRepository = conversationRepository
        let resolvedMetadataStore =
            metadataStore ?? UserDefaultsProjectWorkspaceMetadataStore()
        self.metadataStore = resolvedMetadataStore
        let metadata = resolvedMetadataStore.metadata(for: projectID)
        summary = metadata.summary
    }

    func load() async {
        do {
            conversations = try await conversationRepository
                .conversations(inProject: projectID)
                .sorted { $0.updatedAt > $1.updatedAt }
            errorMessage = nil
        } catch {
            errorMessage = "Proje aktivitesi yüklenemedi."
        }
    }

    func saveContext() {
        metadataStore.save(
            ProjectWorkspaceMetadata(
                summary: summary.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            ),
            for: projectID
        )
    }

    func technologies(from files: [RepositoryFile]) -> [String] {
        let paths = Set(files.map(\.path))
        var values: [String] = []
        if paths.contains(where: { $0.hasSuffix(".xcodeproj/project.pbxproj") })
            || paths.contains(where: { $0.hasSuffix(".swift") }) {
            values.append("Swift")
        }
        if paths.contains("Package.swift") {
            values.append("Swift Package")
        }
        if paths.contains(where: { $0.hasSuffix(".xcworkspace/contents.xcworkspacedata") }) {
            values.append("Xcode Workspace")
        }
        if paths.contains("package.json") {
            values.append("Node.js")
        }
        if paths.contains("Podfile") {
            values.append("CocoaPods")
        }
        return values.isEmpty ? ["Teknoloji algılanmadı"] : values
    }

    func contextFiles(from files: [RepositoryFile]) -> [RepositoryFile] {
        let names = [
            "AGENTS.md", "README.md", "CONTRIBUTING.md",
            "Package.swift", "package.json", ".gitignore"
        ]
        return files.filter { file in
            names.contains { file.path.hasSuffix($0) }
        }
    }

}
