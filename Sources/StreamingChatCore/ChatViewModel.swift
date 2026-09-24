import Foundation
import Observation

/// Holds the chat state and talks to a `ChatStreamingService`.
///
/// The view only reads this state and calls `send()`, `stop()` or `retry()`.
/// All the logic lives here, so it can be tested without any UI.
@MainActor
@Observable
public final class ChatViewModel {
    public private(set) var messages: [ChatMessage]
    public var draft: String = ""
    public private(set) var isStreaming = false
    public private(set) var errorMessage: String?

    private let service: any ChatStreamingService
    @ObservationIgnored private var streamTask: Task<Void, Never>?

    public init(service: any ChatStreamingService, messages: [ChatMessage] = []) {
        self.service = service
        self.messages = messages
    }

    public var canSend: Bool {
        !isStreaming && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// `true` while we wait for the first token of the reply.
    public var isWaitingForFirstToken: Bool {
        isStreaming && (messages.last?.role == .assistant && messages.last?.content.isEmpty == true)
    }

    public func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        draft = ""
        errorMessage = nil
        messages.append(ChatMessage(role: .user, content: text))
        startStreaming()
    }

    public func stop() {
        streamTask?.cancel()
    }

    /// Tries again after an error. It only works when the last message is from the user.
    public func retry() {
        guard !isStreaming, messages.last?.role == .user else { return }
        errorMessage = nil
        startStreaming()
    }

    /// Waits until the current reply ends. Useful in tests.
    func waitForCurrentReply() async {
        let task = streamTask
        await task?.value
    }

    private func startStreaming() {
        let history = messages
        let reply = ChatMessage(role: .assistant, content: "")
        messages.append(reply)
        isStreaming = true

        let service = self.service
        streamTask = Task { [weak self] in
            do {
                for try await token in service.streamReply(for: history) {
                    self?.append(token, to: reply.id)
                }
                self?.finish(replyID: reply.id, error: nil)
            } catch {
                self?.finish(replyID: reply.id, error: error)
            }
        }
    }

    private func append(_ token: String, to id: ChatMessage.ID) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].content += token
    }

    private func finish(replyID: ChatMessage.ID, error: Error?) {
        isStreaming = false
        streamTask = nil

        let replyIsEmpty = messages.first(where: { $0.id == replyID })?.content.isEmpty ?? true
        if replyIsEmpty {
            messages.removeAll { $0.id == replyID }
        }

        if let error, !(error is CancellationError) {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
