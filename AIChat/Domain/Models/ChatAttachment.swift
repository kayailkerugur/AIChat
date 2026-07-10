//
//  ChatAttachment.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 10.07.2026.
//

import Foundation

enum ChatAttachmentKind: String, Codable, Equatable {
    case image
    case document
}

struct ChatAttachment: Identifiable, Equatable {
    let id: UUID
    let fileName: String
    let mimeType: String
    let kind: ChatAttachmentKind
    let data: Data
    let extractedText: String?

    init(
        id: UUID = UUID(),
        fileName: String,
        mimeType: String,
        kind: ChatAttachmentKind,
        data: Data,
        extractedText: String? = nil
    ) {
        self.id = id
        self.fileName = fileName
        self.mimeType = mimeType
        self.kind = kind
        self.data = data
        self.extractedText = extractedText
    }
}
