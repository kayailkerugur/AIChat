//
//  Conversation.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 3.07.2026.
//
//  Provider-agnostic conversation model. Field-by-field mirror of the
//  planned Core Data Conversation entity (spec §5.1), so the Day 11–15
//  mapping stays trivial — same approach as ChatMessage.
//

import Foundation

struct Conversation: Identifiable, Equatable, Hashable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var providerID: String
    var modelID: String

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        providerID: String,
        modelID: String
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.providerID = providerID
        self.modelID = modelID
    }
}
