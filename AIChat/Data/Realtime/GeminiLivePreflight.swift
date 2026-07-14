//
//  GeminiLivePreflight.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 14.07.2026.
//

import Foundation

enum GeminiLivePreflight {

    /// Resolves a model that actually supports the Live/Bidi streaming API
    /// for this account, instead of trusting a hardcoded model name.
    ///
    /// The cached model list in `ProviderConfig` comes from the
    /// OpenAI-compatible `/models` listing, which does not surface
    /// Live-capable models. This calls the native Gemini `models.list`
    /// endpoint and filters by `supportedGenerationMethods` so we only
    /// ever pick a model the key genuinely has Live access to.
    static func resolveLiveModel(apiKey: String) async throws -> String {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "generativelanguage.googleapis.com"
        components.path = "/v1beta/models"
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "pageSize", value: "1000")
        ]

        guard let url = components.url else {
            throw VoicePreflightError("Gemini model listesi adresi oluşturulamadı.")
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw VoicePreflightError("Gemini model listesi yanıtı işlenemedi.")
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = errorMessage(from: data)
                ?? "Gemini model listesi alınamadı. HTTP \(http.statusCode)"
            throw VoicePreflightError(message)
        }

        let payload: ModelsListResponse
        do {
            payload = try JSONDecoder().decode(ModelsListResponse.self, from: data)
        } catch {
            throw VoicePreflightError("Gemini model listesi ayrıştırılamadı.")
        }

        let liveModelNames = payload.models
            .filter { $0.supportedGenerationMethods?.contains("bidiGenerateContent") == true }
            .map { $0.name.replacingOccurrences(of: "models/", with: "") }

        guard let chosen = preferred(among: liveModelNames) else {
            throw VoicePreflightError("Bu API anahtarında Gemini Live (gerçek zamanlı ses) erişimi olan bir model bulunamadı. Google AI Studio üzerinden Live API erişimini kontrol edin.")
        }

        return chosen
    }

    private static func preferred(among liveModelNames: [String]) -> String? {
        if let translate = liveModelNames.first(where: {
            $0.localizedCaseInsensitiveContains("translate")
        }) {
            return translate
        }
        if let flash = liveModelNames.first(where: {
            $0.localizedCaseInsensitiveContains("flash")
        }) {
            return flash
        }
        return liveModelNames.first
    }

    private static func errorMessage(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = object["error"] as? [String: Any]
        else { return nil }

        let status = error["status"] as? String
        let message = error["message"] as? String
        let combined = [status, message]
            .compactMap { $0 }
            .joined(separator: ": ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !combined.isEmpty else { return nil }
        return String(combined.prefix(220))
    }
}

struct VoicePreflightError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}

private struct ModelsListResponse: Decodable {
    let models: [GeminiModelInfo]
}

private struct GeminiModelInfo: Decodable {
    let name: String
    let supportedGenerationMethods: [String]?
}
