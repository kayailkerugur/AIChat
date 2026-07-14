//
//  VoiceCallModels.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 14.07.2026.
//

import Foundation

/// Cascaded voice mode is turn-based (push-to-talk), not a persistent
/// full-duplex session — each state maps to one step of the
/// record → transcribe → send → reply → speak pipeline.
enum VoiceCallStatus: Equatable {
    case idle
    case recording
    case transcribing
    case waitingForReply
    case speaking
    case failed(String)

    var title: String {
        switch self {
        case .idle:
            return "Konuşmak için mikrofona basılı tutun"
        case .recording:
            return "Dinleniyor…"
        case .transcribing:
            return "Metne çevriliyor…"
        case .waitingForReply:
            return "Yanıt bekleniyor…"
        case .speaking:
            return "Yanıt seslendiriliyor…"
        case .failed:
            return "Hata"
        }
    }
}

enum VoiceRealtimeEvent {
    case connected
    case userTranscript(String)
    case assistantTranscript(String)
    case assistantAudio(Data)
    case error(String)
}
