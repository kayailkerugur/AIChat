import Foundation

public struct RepositoryDescriptor: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let displayName: String
    public let rootURL: URL

    public init(
        id: UUID = UUID(),
        displayName: String,
        rootURL: URL
    ) {
        self.id = id
        self.displayName = displayName
        self.rootURL = rootURL
    }
}

public enum RepositoryChangeStatus: String, Codable, Equatable, Sendable {
    case added
    case modified
    case deleted
    case renamed
    case copied
    case untracked
    case conflicted
}

public enum RepositoryChangeArea: String, Codable, Equatable, Sendable {
    case staged
    case unstaged
    case untracked
    case conflicted
}

public struct RepositoryChange: Identifiable, Equatable, Hashable, Sendable {
    public let path: String
    public let originalPath: String?
    public let status: RepositoryChangeStatus
    public let area: RepositoryChangeArea

    public var id: String {
        "\(area.rawValue):\(originalPath ?? "")->\(path)"
    }

    public init(
        path: String,
        originalPath: String? = nil,
        status: RepositoryChangeStatus,
        area: RepositoryChangeArea
    ) {
        self.path = path
        self.originalPath = originalPath
        self.status = status
        self.area = area
    }
}

public struct RepositoryStatus: Equatable, Sendable {
    public let repository: RepositoryDescriptor
    public let branchName: String
    public let headRevision: String?
    public let remoteURL: String?
    public let lastCommitSummary: String?
    public let lastCommitAuthor: String?
    public let lastCommitDate: Date?
    public let changes: [RepositoryChange]

    public init(
        repository: RepositoryDescriptor,
        branchName: String,
        headRevision: String?,
        remoteURL: String? = nil,
        lastCommitSummary: String? = nil,
        lastCommitAuthor: String? = nil,
        lastCommitDate: Date? = nil,
        changes: [RepositoryChange]
    ) {
        self.repository = repository
        self.branchName = branchName
        self.headRevision = headRevision
        self.remoteURL = remoteURL
        self.lastCommitSummary = lastCommitSummary
        self.lastCommitAuthor = lastCommitAuthor
        self.lastCommitDate = lastCommitDate
        self.changes = changes
    }
}

public struct RepositoryFile: Identifiable, Equatable, Hashable, Sendable {
    public let path: String

    public var id: String { path }

    public init(path: String) {
        self.path = path
    }
}

public struct RepositoryFileContent: Equatable, Sendable {
    public let file: RepositoryFile
    public let content: String
    public let wasTruncated: Bool
    public let containsRedactions: Bool

    public init(
        file: RepositoryFile,
        content: String,
        wasTruncated: Bool,
        containsRedactions: Bool
    ) {
        self.file = file
        self.content = content
        self.wasTruncated = wasTruncated
        self.containsRedactions = containsRedactions
    }
}

public enum RepositoryError: LocalizedError, Equatable, Sendable {
    case invalidDirectory
    case invalidPath
    case notGitRepository
    case fileNotFound
    case fileTooLarge
    case binaryFileUnsupported
    case symbolicLinkUnsupported
    case fileAccessUnsupported
    case invalidBookmark
    case staleBookmark
    case securityScopedAccessDenied
    case commandFailed(exitCode: Int32, message: String)
    case invalidOutput

    public var errorDescription: String? {
        switch self {
        case .invalidDirectory:
            return "Repository klasörü geçerli değil."
        case .invalidPath:
            return "Repository dışındaki dosyalara erişilemez."
        case .notGitRepository:
            return "Seçilen klasör bir Git repository değil."
        case .fileNotFound:
            return "Repository dosyası bulunamadı."
        case .fileTooLarge:
            return "Repository dosyası izin verilen boyuttan büyük."
        case .binaryFileUnsupported:
            return "Binary dosyalar sohbet bağlamına eklenemez."
        case .symbolicLinkUnsupported:
            return "Sembolik bağlantılar üzerinden dosya erişimine izin verilmez."
        case .fileAccessUnsupported:
            return "Bu repository sağlayıcısı dosya erişimini desteklemiyor."
        case .invalidBookmark:
            return "Repository erişim kaydı geçerli değil."
        case .staleBookmark:
            return "Repository erişim izni yenilenmeli."
        case .securityScopedAccessDenied:
            return "macOS repository klasörüne erişim izni vermedi."
        case .commandFailed(_, let message):
            return message.isEmpty ? "Git komutu tamamlanamadı." : message
        case .invalidOutput:
            return "Git çıktısı işlenemedi."
        }
    }
}
