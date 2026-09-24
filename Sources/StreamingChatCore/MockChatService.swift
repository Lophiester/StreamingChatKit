import Foundation

/// A fake service for SwiftUI previews and tests. It streams a fixed reply word by word.
public struct MockChatService: ChatStreamingService {
    public var reply: String
    public var delay: Duration
    public var failure: (any Error)?

    public init(
        reply: String = "Hi! This reply is streaming one word at a time, just like a real model.",
        delay: Duration = .milliseconds(60),
        failure: (any Error)? = nil
    ) {
        self.reply = reply
        self.delay = delay
        self.failure = failure
    }

    public func streamReply(for messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        let reply = self.reply
        let delay = self.delay
        let failure = self.failure

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    if let failure {
                        try await Task.sleep(for: delay)
                        throw failure
                    }
                    let words = reply.split(separator: " ", omittingEmptySubsequences: false)
                    for (index, word) in words.enumerated() {
                        try await Task.sleep(for: delay)
                        let separator = index < words.count - 1 ? " " : ""
                        continuation.yield(String(word) + separator)
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
