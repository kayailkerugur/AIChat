//
//  MockAIProvider.swift
//  AIChat
//
//  Created by Ilker Ugur Kaya on 3.07.2026.
//
//  Fake AI provider used for Days 6–15 and forever after in tests,
//  previews and the final "swap providers" demo. Streams canned
//  responses word by word with configurable speed and failure points.
//
//  Same philosophy as MockAuthService: a Behavior struct makes every
//  UI state (streaming, error mid-stream, cancellation) reproducible
//  without touching real APIs.
//

import Foundation

@MainActor
public final class MockAIProvider: AIProvider {
    public func refreshModels() async throws -> [AIModel] {
        return []
    }
    

    // MARK: - Configuration

    public struct Behavior: Sendable {
        /// Delay between emitted chunks. ~0.05–0.15s feels realistic.
        public var chunkDelay: Duration

        /// If set, the stream throws this error after `failAfterChunks` chunks.
        public var failure: AIError?
        public var failAfterChunks: Int

        /// Emit a fake TokenUsage event before completing.
        public var reportsUsage: Bool

        /// Fixed response override. When nil, a canned response is picked
        /// based on the user's message (so demos look varied).
        public var fixedResponse: String?

        public init(
            chunkDelay: Duration = .milliseconds(80),
            failure: AIError? = nil,
            failAfterChunks: Int = 8,
            reportsUsage: Bool = true,
            fixedResponse: String? = nil
        ) {
            self.chunkDelay = chunkDelay
            self.failure = failure
            self.failAfterChunks = failAfterChunks
            self.reportsUsage = reportsUsage
            self.fixedResponse = fixedResponse
        }
    }

    public var behavior: Behavior

    // MARK: - AIProvider

    public let id = "mock"
    public let supportsImages = true

    public let supportedModels: [AIModel] = [
        AIModel(id: "mock-fast", displayName: "Mock Fast", providerID: "mock"),
        AIModel(id: "mock-smart", displayName: "Mock Smart", providerID: "mock"),
    ]

    private var currentTask: Task<Void, Never>?

    public init(behavior: Behavior = Behavior()) {
        self.behavior = behavior
    }

    public func stream(request: ChatRequest) -> AsyncThrowingStream<AIStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task { [behavior] in
                do {
                    let response = behavior.fixedResponse
                        ?? Self.cannedResponse(for: request.messages.last?.content ?? "")

                    // Split into word-ish chunks, keeping whitespace so the
                    // reassembled text is identical to the original.
                    let chunks = Self.chunked(response)

                    for (index, chunk) in chunks.enumerated() {
                        try Task.checkCancellation()

                        if let failure = behavior.failure,
                           index == behavior.failAfterChunks {
                            throw failure
                        }

                        continuation.yield(.textDelta(chunk))
                        try await Task.sleep(for: behavior.chunkDelay)
                    }

                    if behavior.reportsUsage {
                        continuation.yield(.usage(TokenUsage(
                            inputTokens: request.messages.reduce(0) { $0 + $1.content.count / 4 },
                            outputTokens: response.count / 4
                        )))
                    }

                    continuation.yield(.completed)
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish(throwing: AIError.cancelled)
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            currentTask = task
            // If the consumer stops iterating (Task cancelled or stream dropped),
            // make sure our producer task stops too.
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    public func cancelCurrentRequest() {
        currentTask?.cancel()
        currentTask = nil
    }

    // MARK: - Canned content

    private static func chunked(_ text: String) -> [String] {
        // Split after every space so chunks carry their trailing whitespace.
        var chunks: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if character == " " || character == "\n" {
                chunks.append(current)
                current = ""
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }

    private static func cannedResponse(for prompt: String) -> String {
        let lowered = prompt.lowercased()

        if lowered.contains("kod") || lowered.contains("code") || lowered.contains("swift") {
            return """
            Elbette! İşte Swift ile basit bir örnek:

            ```swift
            struct Greeter {
                let name: String

                func greet() -> String {
                    "Merhaba, \\(name)!"
                }
            }

            let greeter = Greeter(name: "Dünya")
            print(greeter.greet())
            ```

            Bu örnekte `Greeter` yapısı bir `name` alanı tutar ve \
            `greet()` metodu selamlama metni üretir. Başka bir örnek \
            isterseniz söylemeniz yeterli.
            """
        }

        if lowered.contains("liste") || lowered.contains("madde") {
            return """
            Tabii, işte istediğiniz liste:

            1. **Birinci madde** — en önemli nokta genellikle budur.
            2. **İkinci madde** — detaylar burada devreye girer.
            3. **Üçüncü madde** — ve son olarak bu.

            Her maddeyi ayrıca açabilirim, hangisiyle devam edelim?
            """
        }

        return """
        Bu, mock sağlayıcıdan gelen simüle edilmiş bir yanıttır. \
        Gerçek bir AI servisine bağlanmadan streaming davranışını, \
        *Markdown* desteğini ve **iptal akışını** test etmenizi sağlar.

        Yanıt kelime kelime ekrana gelir; bu sırada durdur butonuna \
        basarak iptal davranışını da deneyebilirsiniz. Kod bloğu \
        denemek için mesajınızda "kod" kelimesini kullanın.
        """
    }
}
