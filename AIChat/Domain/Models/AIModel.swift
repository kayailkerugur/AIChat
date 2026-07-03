//
//  AIModel.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 3.07.2026.
//

import Foundation

struct AIModel: Identifiable, Equatable, Hashable {
    /// Provider-side identifier sent in requests (e.g. "gpt-4o-mini").
    let id: String
    /// Human-readable name shown in the UI (e.g. "GPT-4o mini").
    let displayName: String
    /// Which provider owns this model. Matches AIProvider.id.
    let providerID: String
}
