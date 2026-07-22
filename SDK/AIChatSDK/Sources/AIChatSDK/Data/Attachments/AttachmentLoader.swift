//
//  AttachmentLoader.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 10.07.2026.
//

import Foundation
import PDFKit
import UniformTypeIdentifiers

public enum AttachmentLoader {

    public static let allowedContentTypes: [UTType] = [
        .image,
        .pdf,
        .plainText,
        .text,
        .json,
        .commaSeparatedText,
        .data,
    ]

    public static func load(from url: URL) throws -> ChatAttachment {
        let didStartAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if didStartAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let data = try Data(contentsOf: url)
        let type = UTType(filenameExtension: url.pathExtension)
        let mimeType = type?.preferredMIMEType ?? "application/octet-stream"
        let fileName = url.lastPathComponent

        if type?.conforms(to: .image) == true {
            return ChatAttachment(
                fileName: fileName,
                mimeType: mimeType,
                kind: .image,
                data: data
            )
        }

        return ChatAttachment(
            fileName: fileName,
            mimeType: mimeType,
            kind: .document,
            data: data,
            extractedText: extractText(from: data, type: type)
        )
    }

    private static func extractText(from data: Data, type: UTType?) -> String? {
        if type?.conforms(to: .pdf) == true {
            return PDFDocument(data: data)?.string
        }

        if type?.conforms(to: .text) == true ||
            type?.conforms(to: .json) == true ||
            type?.conforms(to: .commaSeparatedText) == true {
            return String(data: data, encoding: .utf8)
        }

        return nil
    }
}
