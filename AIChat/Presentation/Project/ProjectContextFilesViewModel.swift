import AIChatSDK
import Foundation
import Observation

@MainActor
@Observable
final class ProjectContextFilesViewModel {
    private(set) var files: [RepositoryFile] = []
    private(set) var selectedFile: RepositoryFile?
    private(set) var isLoading = false
    private(set) var isSaving = false
    private(set) var infoMessage: String?
    private(set) var errorMessage: String?
    var content = ""

    var hasChanges: Bool {
        selectedFile != nil && content != originalContent
    }

    var canSave: Bool {
        hasChanges && !isLoading && !isSaving
    }

    private let repositoryProvider: any RepositoryProvider
    private let projectID: UUID
    private let maximumByteCount: Int
    private var originalContent = ""
    private var repositoryClient: (any RepositoryClient)?

    init(
        repositoryProvider: any RepositoryProvider,
        projectID: UUID,
        maximumByteCount: Int = 200_000
    ) {
        self.repositoryProvider = repositoryProvider
        self.projectID = projectID
        self.maximumByteCount = maximumByteCount
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let client = try await repositoryProvider.repositoryClient(
                forProject: projectID
            )
            repositoryClient = client
            files = try await client.files()
                .filter(Self.isContextFile)
                .sorted {
                    $0.path.localizedStandardCompare($1.path)
                        == .orderedAscending
                }
            errorMessage = nil

            if let selectedFile,
               files.contains(selectedFile) {
                await select(selectedFile)
            } else if let first = files.first {
                await select(first)
            } else {
                self.selectedFile = nil
                content = ""
                originalContent = ""
            }
        } catch {
            repositoryClient = nil
            files = []
            selectedFile = nil
            content = ""
            originalContent = ""
            errorMessage = Self.message(for: error)
        }
    }

    func select(_ file: RepositoryFile) async {
        guard !hasChanges || file == selectedFile else {
            errorMessage =
                "Önce mevcut değişiklikleri kaydedin veya geri alın."
            return
        }
        guard let reader = repositoryClient
            as? any RepositoryContextFileWriting else {
            errorMessage = RepositoryError.fileWriteUnsupported
                .errorDescription
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await reader.readContextFile(
                at: file.path,
                maximumByteCount: maximumByteCount
            )
            guard !result.wasTruncated else {
                throw RepositoryError.fileTooLarge
            }
            selectedFile = file
            content = result.content
            originalContent = result.content
            infoMessage = nil
            errorMessage = nil
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func save() async {
        guard let selectedFile,
              let writer = repositoryClient
                as? any RepositoryContextFileWriting else {
            errorMessage = RepositoryError.fileWriteUnsupported
                .errorDescription
            return
        }
        isSaving = true
        defer { isSaving = false }
        do {
            try await writer.writeContextFile(
                at: selectedFile.path,
                content: content,
                maximumByteCount: maximumByteCount
            )
            originalContent = content
            infoMessage = "\(selectedFile.path) kaydedildi."
            errorMessage = nil
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    func revert() {
        content = originalContent
        errorMessage = nil
    }

    private static func isContextFile(_ file: RepositoryFile) -> Bool {
        let name = URL(fileURLWithPath: file.path).lastPathComponent
        let exactNames: Set<String> = [
            "AGENTS.md", "README.md", "CONTRIBUTING.md",
            "Package.swift", "package.json", ".gitignore"
        ]
        return exactNames.contains(name)
            || name.hasSuffix(".context.md")
            || name.hasSuffix(".instructions.md")
    }

    private static func message(for error: Error) -> String {
        (error as? LocalizedError)?.errorDescription
            ?? "Bağlam dosyası işlemi tamamlanamadı."
    }
}
