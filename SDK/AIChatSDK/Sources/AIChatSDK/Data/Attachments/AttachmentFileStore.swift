import Foundation

public struct AttachmentFileStore: Sendable {
    public let rootDirectory: URL

    public init(rootDirectory: URL) {
        self.rootDirectory = rootDirectory
    }

    public static func applicationSupport(appIdentifier: String) -> AttachmentFileStore {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
        return AttachmentFileStore(rootDirectory: appSupport
            .appendingPathComponent(appIdentifier, isDirectory: true)
            .appendingPathComponent("Attachments", isDirectory: true))
    }

    public func write(
        data: Data,
        fileName: String,
        attachmentID: UUID,
        messageID: UUID
    ) throws -> String {
        let relativePath = "\(messageID.uuidString)/\(attachmentID.uuidString)-\(safeFileName(fileName))"
        let url = fileURL(for: relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
        return relativePath
    }

    public func read(relativePath: String) -> Data? {
        try? Data(contentsOf: fileURL(for: relativePath))
    }

    public func delete(relativePath: String?) {
        guard let relativePath else { return }
        let url = fileURL(for: relativePath)
        try? FileManager.default.removeItem(at: url)
        removeParentDirectoryIfEmpty(for: url)
    }

    private func fileURL(for relativePath: String) -> URL {
        let cleanPath = relativePath
            .split(separator: "/")
            .map(String.init)
            .map(safeFileName)
            .joined(separator: "/")
        return rootDirectory.appendingPathComponent(cleanPath)
    }

    private func safeFileName(_ fileName: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:")
            .union(.newlines)
            .union(.controlCharacters)
        let sanitized = fileName
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? "attachment" : sanitized
    }

    private func removeParentDirectoryIfEmpty(for fileURL: URL) {
        let directory = fileURL.deletingLastPathComponent()
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ), contents.isEmpty else { return }
        try? FileManager.default.removeItem(at: directory)
    }
}
