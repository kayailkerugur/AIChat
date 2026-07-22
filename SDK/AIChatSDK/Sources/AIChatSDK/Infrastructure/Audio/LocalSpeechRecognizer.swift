//
//  LocalSpeechRecognizer.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 14.07.2026.
//
//  On-device speech-to-text via Apple's Speech framework. Cascaded voice
//  mode uses this instead of a provider's `/audio/transcriptions`
//  endpoint — no network call, no per-provider model-name guessing, no
//  way to 404.
//

import AVFoundation
import Foundation
import Speech

@MainActor
public final class LocalSpeechRecognizer: SpeechRecognizer {

    private let recognizer: SFSpeechRecognizer?
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var continuation: CheckedContinuation<String, Error>?

    public init(localeIdentifier: String = "tr-TR") {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
            ?? SFSpeechRecognizer(locale: .current)
            ?? SFSpeechRecognizer()
    }

    /// Speech recognition and microphone access are separate privacy
    /// grants on macOS — both are required before `startRecording()`.
    public func requestAuthorization() async -> Bool {
        let speechAuthorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechAuthorized else { return false }

        return await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    public func startRecording() throws {
        guard let recognizer, recognizer.isAvailable else {
            throw LocalSpeechRecognizerError.unavailable
        }

        task?.cancel()
        task = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = false
        // Prefer fully offline recognition when the locale's on-device
        // model is available; falls back to Apple's server-assisted
        // recognition otherwise (still no dependency on the chat provider).
        request.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
        self.request = request

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            Task { @MainActor in
                if let error {
                    self.finish(.failure(error))
                } else if let result, result.isFinal {
                    self.finish(.success(result.bestTranscription.formattedString))
                }
            }
        }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    public func stopAndRecognize() async throws -> String {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
        }
    }

    private func finish(_ result: Result<String, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        task = nil
        request = nil
        switch result {
        case .success(let text):
            continuation.resume(returning: text)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}

public enum LocalSpeechRecognizerError: LocalizedError, Sendable {
    case unavailable

    public var errorDescription: String? {
        "Bu cihazda/dilde konuşma tanıma kullanılamıyor."
    }
}
