import Foundation

/// Reads the text from one streaming chunk of an OpenAI compatible API.
enum OpenAIChunkDecoder {
    private struct Chunk: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable {
                let content: String?
            }
            let delta: Delta
        }
        let choices: [Choice]
    }

    /// Returns the new text in this chunk, or `nil` when the chunk has no text.
    static func token(from data: String) throws -> String? {
        let chunk = try JSONDecoder().decode(Chunk.self, from: Data(data.utf8))
        guard let content = chunk.choices.first?.delta.content, !content.isEmpty else {
            return nil
        }
        return content
    }
}

enum OpenAIRequestBuilder {
    private struct Body: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }
        let model: String
        let stream: Bool
        let messages: [Message]
    }

    static func makeRequest(
        messages: [ChatMessage],
        configuration: OpenAICompatibleService.Configuration
    ) throws -> URLRequest {
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")

        let body = Body(
            model: configuration.model,
            stream: true,
            messages: messages.map { .init(role: $0.role.rawValue, content: $0.content) }
        )
        request.httpBody = try JSONEncoder().encode(body)
        return request
    }
}

/// Streams replies from any API that follows the OpenAI chat completions format.
///
/// In a real app, do not ship your API key inside the binary.
/// Point `baseURL` to your own backend (for example a Cloud Function) that adds the key.
public struct OpenAICompatibleService: ChatStreamingService {
    public struct Configuration: Sendable {
        public var baseURL: URL
        public var apiKey: String
        public var model: String

        public init(baseURL: URL, apiKey: String, model: String) {
            self.baseURL = baseURL
            self.apiKey = apiKey
            self.model = model
        }
    }

    public let configuration: Configuration

    public init(configuration: Configuration) {
        self.configuration = configuration
    }

    public func streamReply(for messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        #if canImport(Darwin)
        let configuration = self.configuration
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try OpenAIRequestBuilder.makeRequest(messages: messages, configuration: configuration)
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        throw ChatError.invalidResponse
                    }
                    guard (200..<300).contains(http.statusCode) else {
                        throw ChatError.httpStatus(http.statusCode)
                    }

                    for try await event in bytes.sseLines.serverSentEvents {
                        if event.data == "[DONE]" { break }
                        if let token = try OpenAIChunkDecoder.token(from: event.data) {
                            continuation.yield(token)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
        #else
        return AsyncThrowingStream { $0.finish(throwing: ChatError.invalidResponse) }
        #endif
    }
}
