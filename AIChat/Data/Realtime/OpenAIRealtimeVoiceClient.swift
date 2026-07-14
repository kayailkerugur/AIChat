//
//  OpenAIRealtimeVoiceClient.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 14.07.2026.
//

import Foundation

final class OpenAIRealtimeVoiceClient: NSObject, VoiceRealtimeClient, URLSessionWebSocketDelegate {

    let inputSampleRate: Double = 24_000
    let outputSampleRate: Double = 24_000

    private let apiKey: String
    private let model: String
    private lazy var urlSession = URLSession(
        configuration: .default,
        delegate: self,
        delegateQueue: nil
    )
    private var webSocketTask: URLSessionWebSocketTask?
    private var receiveTask: Task<Void, Never>?
    private var continuation: AsyncStream<VoiceRealtimeEvent>.Continuation?

    init(
        apiKey: String,
        model: String = "gpt-realtime-2.1"
    ) {
        self.apiKey = apiKey
        self.model = model
        super.init()
    }

    func connect() -> AsyncStream<VoiceRealtimeEvent> {
        AsyncStream { continuation in
            self.continuation = continuation

            var components = URLComponents()
            components.scheme = "wss"
            components.host = "api.openai.com"
            components.path = "/v1/realtime"
            components.queryItems = [
                URLQueryItem(name: "model", value: model)
            ]

            guard let url = components.url else {
                continuation.yield(.error("Realtime bağlantı adresi oluşturulamadı."))
                continuation.finish()
                return
            }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.assumesHTTP3Capable = false

            let task = urlSession.webSocketTask(with: request)
            webSocketTask = task
            task.resume()

            continuation.onTermination = { [weak self] _ in
                guard let client = self else { return }
                Task { @MainActor [client] in
                    client.disconnect()
                }
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        Task { @MainActor [weak self] in
            self?.receiveTask = Task { [weak self] in
                await self?.receiveLoop()
            }
            await self?.sendSessionUpdate()
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        let reasonText = reason.flatMap { String(data: $0, encoding: .utf8) }
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.continuation?.yield(.error(
                "Realtime bağlantısı kapandı. Kod: \(closeCode.rawValue)" +
                    (reasonText.map { " - \($0)" } ?? "")
            ))
            self.continuation?.finish()
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.continuation?.yield(.error("Realtime bağlantısı kurulamadı: \(error.localizedDescription)"))
            self.continuation?.finish()
        }
    }

    func sendAudio(_ pcm16Audio: Data) async {
        let payload: [String: Any] = [
            "type": "input_audio_buffer.append",
            "audio": pcm16Audio.base64EncodedString()
        ]
        await sendJSON(payload)
    }

    func disconnect() {
        receiveTask?.cancel()
        receiveTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        continuation?.finish()
        continuation = nil
    }

    private func sendSessionUpdate() async {
        let payload: [String: Any] = [
            "type": "session.update",
            "session": [
                "type": "realtime",
                "instructions": "You are a helpful voice assistant inside a macOS chat app. Keep answers concise and conversational. Speak Turkish unless the user uses another language.",
                "audio": [
                    "input": [
                        "format": [
                            "type": "audio/pcm",
                            "rate": 24000
                        ],
                        "turn_detection": [
                            "type": "server_vad",
                            "create_response": true,
                            "interrupt_response": true
                        ],
                        "transcription": [
                            "model": "gpt-4o-mini-transcribe"
                        ]
                    ],
                    "output": [
                        "format": [
                            "type": "audio/pcm",
                            "rate": 24000
                        ],
                        "voice": "alloy"
                    ]
                ]
            ]
        ]
        await sendJSON(payload)
    }

    private func sendJSON(_ payload: [String: Any]) async {
        guard let webSocketTask else { return }
        do {
            let data = try JSONSerialization.data(withJSONObject: payload)
            guard let string = String(data: data, encoding: .utf8) else { return }
            try await webSocketTask.send(.string(string))
        } catch {
            continuation?.yield(.error("Realtime isteği gönderilemedi: \(error.localizedDescription)"))
            disconnect()
        }
    }

    private func receiveLoop() async {
        guard let webSocketTask else { return }

        while !Task.isCancelled {
            do {
                let message = try await webSocketTask.receive()
                switch message {
                case .string(let text):
                    handle(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        handle(text)
                    }
                @unknown default:
                    break
                }
            } catch {
                if !Task.isCancelled {
                    continuation?.yield(.error("Realtime bağlantısı kapandı: \(error.localizedDescription)"))
                    continuation?.finish()
                }
                return
            }
        }
    }

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String
        else { return }

        if type == "error" {
            let message = ((object["error"] as? [String: Any])?["message"] as? String)
                ?? "Realtime servisinde hata oluştu."
            continuation?.yield(.error(message))
            return
        }

        if type == "session.created" || type == "session.updated" {
            continuation?.yield(.connected)
            return
        }

        if type == "response.audio.delta",
           let base64 = object["delta"] as? String,
           let audio = Data(base64Encoded: base64) {
            continuation?.yield(.assistantAudio(audio))
            return
        }

        if type == "response.audio_transcript.delta",
           let delta = object["delta"] as? String {
            continuation?.yield(.assistantTranscript(delta))
            return
        }

        if type == "response.output_text.delta",
           let delta = object["delta"] as? String {
            continuation?.yield(.assistantTranscript(delta))
            return
        }

        if type == "conversation.item.input_audio_transcription.completed",
           let transcript = object["transcript"] as? String {
            continuation?.yield(.userTranscript(transcript))
        }
    }
}
