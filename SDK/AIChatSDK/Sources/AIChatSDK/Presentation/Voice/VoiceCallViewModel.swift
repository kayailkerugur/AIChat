//
//  VoiceCallViewModel.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 14.07.2026.
//
//  Cascaded voice mode: push-to-talk speech is transcribed on-device
//  (LocalSpeechRecognizer), sent through the conversation's normal chat
//  pipeline exactly like a typed message, and the reply is read back
//  on-device (LocalSpeechSynthesizer). Only the actual chat completion
//  goes over the network — through whichever provider the conversation
//  already uses, the same path a typed message takes.
//

import Foundation
import Observation

@MainActor
@Observable
public final class VoiceCallViewModel {

    public private(set) var status: VoiceCallStatus = .idle
    public private(set) var isRecording = false
    public private(set) var isSpeechPaused = false
    public private(set) var lastUserTranscript = ""
    public private(set) var lastAssistantReply = ""
    public let activeModelName: String?

    public var isBusy: Bool {
        switch status {
        case .transcribing, .waitingForReply, .speaking:
            return true
        case .idle, .recording, .failed:
            return false
        }
    }

    /// Recording a new turn is allowed any time except mid-pipeline for
    /// the *previous* turn (transcribing it, or waiting on its reply) —
    /// including while the previous reply is still being read aloud, so
    /// the user can barge in and ask something else without waiting for
    /// playback to finish.
    public var canStartRecording: Bool {
        switch status {
        case .transcribing, .waitingForReply:
            return false
        case .idle, .recording, .speaking, .failed:
            return true
        }
    }

    private let chatViewModel: ChatViewModel
    private let speechRecognizer: any SpeechRecognizer
    private let speechSynthesizer: any SpeechSynthesizer

    public init(chatViewModel: ChatViewModel) {
        self.chatViewModel = chatViewModel
        self.speechRecognizer = LocalSpeechRecognizer()
        self.speechSynthesizer = LocalSpeechSynthesizer()
        self.activeModelName = "Cihazda ASR/TTS · \(chatViewModel.conversation.modelID)"
    }

    public init(
        chatViewModel: ChatViewModel,
        speechRecognizer: any SpeechRecognizer,
        speechSynthesizer: any SpeechSynthesizer
    ) {
        self.chatViewModel = chatViewModel
        self.speechRecognizer = speechRecognizer
        self.speechSynthesizer = speechSynthesizer
        self.activeModelName = "Cihazda ASR/TTS · \(chatViewModel.conversation.modelID)"
    }

    public func startRecording() {
        guard !isRecording, canStartRecording else { return }

        // Barge-in: cut the current reply off instead of waiting for it
        // to finish. sendAndSpeak() checks `status` before resetting it
        // to `.idle` once speech ends, so it won't clobber the `.recording`
        // state this is about to set.
        if status == .speaking {
            speechSynthesizer.stop()
            isSpeechPaused = false
        }
        status = .recording

        Task {
            guard await speechRecognizer.requestAuthorization() else {
                status = .failed("Mikrofon veya konuşma tanıma izni verilmedi.")
                return
            }
            do {
                try speechRecognizer.startRecording()
                isRecording = true
                status = .recording
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }

    public func stopRecordingAndSend() {
        guard isRecording else { return }
        isRecording = false
        status = .transcribing

        Task {
            do {
                let transcript = try await speechRecognizer.stopAndRecognize()
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !transcript.isEmpty else {
                    status = .idle
                    return
                }
                lastUserTranscript = transcript
                await sendAndSpeak(transcript: transcript)
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }

    public func stopSpeakingAndReset() {
        speechSynthesizer.stop()
        isSpeechPaused = false
        if !isBusy {
            status = .idle
        }
    }

    public func togglePauseResume() {
        guard status == .speaking else { return }
        if isSpeechPaused {
            speechSynthesizer.resumeSpeaking()
            isSpeechPaused = false
        } else {
            speechSynthesizer.pause()
            isSpeechPaused = true
        }
    }

    // MARK: - Send through the real chat pipeline, then speak the reply

    private func sendAndSpeak(transcript: String) async {
        status = .waitingForReply
        chatViewModel.draft = transcript
        chatViewModel.sendDraft()

        // sendDraft() flips isStreaming to true synchronously before
        // returning (it starts the placeholder + stream task inline), so
        // waiting for it to flip back false reliably means this exact
        // reply — not some earlier one — has reached a terminal state.
        while chatViewModel.isStreaming {
            try? await Task.sleep(nanoseconds: 150_000_000)
        }

        guard let reply = chatViewModel.messages.last(where: { $0.role == .assistant }),
              reply.status == .completed,
              !reply.content.isEmpty
        else {
            status = .idle
            return
        }
        lastAssistantReply = reply.content

        status = .speaking
        isSpeechPaused = false
        await speechSynthesizer.speak(reply.content)
        isSpeechPaused = false
        // A barge-in during playback already moved status past `.speaking`
        // (to `.recording`) — don't stomp on it.
        if status == .speaking {
            status = .idle
        }
    }
}
