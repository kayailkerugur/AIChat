//
//  GeminiLiveVoiceClient.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 14.07.2026.
//

import Foundation

final class GeminiLiveVoiceClient: NSObject, VoiceRealtimeClient, URLSessionWebSocketDelegate {

    let inputSampleRate: Double = 16_000
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
        model: String = "gemini-3.1-flash-live-preview"
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
            components.host = "generativelanguage.googleapis.com"
            components.path = "/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent"
            components.queryItems = [
                URLQueryItem(name: "key", value: apiKey)
            ]

            guard let url = components.url else {
                continuation.yield(.error("Gemini Live bağlantı adresi oluşturulamadı."))
                continuation.finish()
                return
            }

            // Google's endpoint advertises HTTP/3, but URLSessionWebSocketTask's
            // opportunistic QUIC upgrade for this host frequently reports the
            // handshake as open and then immediately fails the underlying
            // socket ("Socket is not connected"). Forcing HTTP/1.1/2 avoids it.
            var request = URLRequest(url: url)
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
            await self?.sendSetup()
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
                "Gemini Live bağlantısı kapandı. Kod: \(closeCode.rawValue)" +
                    (reasonText.map { " - \($0)" } ?? "")
            ))
            self.continuation?.finish()
        }
    }

    // Without this, a handshake that fails outright (never reaches
    // didOpenWithProtocol) leaves the call stuck on "Bağlanıyor" forever —
    // no .error event is ever produced for it otherwise.
    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.continuation?.yield(.error("Gemini Live bağlantısı kurulamadı: \(error.localizedDescription)"))
            self.continuation?.finish()
        }
    }

    func sendAudio(_ pcm16Audio: Data) async {
        let payload: [String: Any] = [
            "realtimeInput": [
                "audio": [
                    "data": pcm16Audio.base64EncodedString(),
                    "mimeType": "audio/pcm;rate=16000"
                ]
            ]
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

    private func sendSetup() async {
        let payload: [String: Any] = [
            "setup": [
                "model": "models/\(model)",
                "responseModalities": ["AUDIO"],
                "systemInstruction": [
                    "parts": [
                        [
                            "text": "You are a real-time voice assistant inside a macOS chat app. If the user speaks Turkish, respond in Turkish. If the user speaks another language, translate or answer naturally in Turkish unless they ask for a different target language."
                        ]
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
            continuation?.yield(.error("Gemini Live isteği gönderilemedi: \(error.localizedDescription)"))
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
                    let message = error.localizedDescription
                    if message.localizedCaseInsensitiveContains("socket is not connected") {
                        continuation?.yield(.error("Gemini Live bağlantısı açılamadı. API anahtarının Live API/WebSocket erişimi, model erişimi veya proje kısıtlarını kontrol edin."))
                    } else {
                        continuation?.yield(.error("Gemini Live bağlantısı kapandı: \(message)"))
                    }
                    continuation?.finish()
                }
                return
            }
        }
    }

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        if let error = object["error"] as? [String: Any] {
            continuation?.yield(.error((error["message"] as? String) ?? "Gemini Live servisinde hata oluştu."))
            return
        }

        if object["setupComplete"] != nil {
            continuation?.yield(.connected)
            return
        }

        guard let serverContent = object["serverContent"] as? [String: Any] else { return }

        if let inputTranscription = serverContent["inputTranscription"] as? [String: Any],
           let text = inputTranscription["text"] as? String {
            continuation?.yield(.userTranscript(text))
        }

        if let outputTranscription = serverContent["outputTranscription"] as? [String: Any],
           let text = outputTranscription["text"] as? String {
            continuation?.yield(.assistantTranscript(text))
        }

        guard let modelTurn = serverContent["modelTurn"] as? [String: Any],
              let parts = modelTurn["parts"] as? [[String: Any]]
        else { return }

        for part in parts {
            guard let inlineData = part["inlineData"] as? [String: Any],
                  let base64 = inlineData["data"] as? String,
                  let audio = Data(base64Encoded: base64)
            else { continue }
            continuation?.yield(.assistantAudio(audio))
        }
    }
}
