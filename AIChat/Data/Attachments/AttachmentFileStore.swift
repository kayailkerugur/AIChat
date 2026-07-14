//
//  AttachmentFileStore.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 14.07.2026.
//

import Foundation

enum AttachmentFileStore {

    nonisolated private static let rootFolderName = "Attachments"

    nonisolated static func write(
        data: Data,
        fileName: String,
        attachmentID: UUID,
        messageID: UUID
    ) throws -> String {
        let relativePath = "\(messageID.uuidString)/\(attachmentID.uuidString)-\(safeFileName(fileName))"
        let url = try fileURL(for: relativePath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
        return relativePath
    }

    nonisolated static func read(relativePath: String) -> Data? {
        guard let url = try? fileURL(for: relativePath) else { return nil }
        return try? Data(contentsOf: url)
    }

    nonisolated static func delete(relativePath: String?) {
        guard let relativePath,
              let url = try? fileURL(for: relativePath)
        else { return }
        try? FileManager.default.removeItem(at: url)
        removeParentDirectoryIfEmpty(for: url)
    }

    nonisolated private static func fileURL(for relativePath: String) throws -> URL {
        let cleanPath = relativePath
            .split(separator: "/")
            .map(String.init)
            .map(safeFileName)
            .joined(separator: "/")
        return try rootDirectory().appendingPathComponent(cleanPath)
    }

    nonisolated private static func rootDirectory() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let bundleFolder = Bundle.main.bundleIdentifier ?? "AIChat"
        let url = appSupport
            .appendingPathComponent(bundleFolder, isDirectory: true)
            .appendingPathComponent(rootFolderName, isDirectory: true)
        try FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        return url
    }

    nonisolated private static func safeFileName(_ fileName: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: "/:")
            .union(.newlines)
            .union(.controlCharacters)
        let sanitized = fileName
            .components(separatedBy: invalidCharacters)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? "attachment" : sanitized
    }

    nonisolated private static func removeParentDirectoryIfEmpty(for fileURL: URL) {
        let directory = fileURL.deletingLastPathComponent()
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ), contents.isEmpty else { return }
        try? FileManager.default.removeItem(at: directory)
    }
}
