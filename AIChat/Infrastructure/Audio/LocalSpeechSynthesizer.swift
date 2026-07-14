//
//  LocalSpeechSynthesizer.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 14.07.2026.
//
//  On-device text-to-speech via AVSpeechSynthesizer. Cascaded voice mode
//  uses this instead of a provider's `/audio/speech` endpoint — no
//  network call, no per-provider voice-name guessing, no way to 404.
//

import AVFoundation
import Foundation

@MainActor
final class LocalSpeechSynthesizer: NSObject, AVSpeechSynthesizerDelegate {

    private let synthesizer = AVSpeechSynthesizer()
    private var continuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Suspends until the utterance finishes, is cancelled, or `stop()`
    /// is called — whichever comes first.
    func speak(_ text: String) async {
        stop()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "tr-TR")
            ?? AVSpeechSynthesisVoice(language: Locale.current.identifier)

        await withCheckedContinuation { continuation in
            self.continuation = continuation
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        finishWaiting()
    }

    var isPaused: Bool { synthesizer.isPaused }

    func pause() {
        guard synthesizer.isSpeaking, !synthesizer.isPaused else { return }
        synthesizer.pauseSpeaking(at: .word)
    }

    func resumeSpeaking() {
        guard synthesizer.isPaused else { return }
        synthesizer.continueSpeaking()
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            self?.finishWaiting()
        }
    }

    nonisolated func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor [weak self] in
            self?.finishWaiting()
        }
    }

    private func finishWaiting() {
        continuation?.resume()
        continuation = nil
    }
}
