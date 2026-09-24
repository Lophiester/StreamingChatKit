import Foundation
import Testing
@testable import StreamingChatCore

@MainActor
@Suite("Chat view model")
struct ChatViewModelTests {
    @Test func sendStreamsTheWholeReply() async {
        let viewModel = ChatViewModel(service: MockChatService(reply: "Hello there friend", delay: .zero))
        viewModel.draft = "  Hi  "

        viewModel.send()
        #expect(viewModel.isStreaming)
        #expect(viewModel.draft.isEmpty)

        await viewModel.waitForCurrentReply()

        #expect(viewModel.isStreaming == false)
        #expect(viewModel.messages.map(\.role) == [.user, .assistant])
        #expect(viewModel.messages[0].content == "Hi")
        #expect(viewModel.messages[1].content == "Hello there friend")
        #expect(viewModel.errorMessage == nil)
    }

    @Test func emptyDraftDoesNothing() {
        let viewModel = ChatViewModel(service: MockChatService(delay: .zero))
        viewModel.draft = "   \n "

        #expect(viewModel.canSend == false)
        viewModel.send()
        #expect(viewModel.messages.isEmpty)
    }

    @Test func errorShowsAMessageAndRemovesTheEmptyReply() async {
        let viewModel = ChatViewModel(service: MockChatService(delay: .zero, failure: ChatError.httpStatus(500)))
        viewModel.draft = "Hi"

        viewModel.send()
        await viewModel.waitForCurrentReply()

        #expect(viewModel.messages.map(\.role) == [.user])
        #expect(viewModel.errorMessage?.contains("CHAT-HTTP-500") == true)
    }

    @Test func retryOnlyWorksAfterAUserMessage() async {
        let viewModel = ChatViewModel(
            service: MockChatService(reply: "ok", delay: .zero),
            messages: [ChatMessage(role: .user, content: "Hi")]
        )

        viewModel.retry()
        await viewModel.waitForCurrentReply()
        #expect(viewModel.messages.last?.content == "ok")

        viewModel.retry()
        #expect(viewModel.isStreaming == false)
    }

    @Test func stopKeepsThePartialReply() async throws {
        let viewModel = ChatViewModel(service: MockChatService(reply: "one two three four five", delay: .milliseconds(50)))
        viewModel.draft = "Hi"

        viewModel.send()
        try await Task.sleep(for: .milliseconds(120))
        viewModel.stop()
        await viewModel.waitForCurrentReply()

        #expect(viewModel.isStreaming == false)
        #expect(viewModel.errorMessage == nil)
        let reply = viewModel.messages.last
        #expect(reply?.role == .assistant)
        #expect(reply?.content.isEmpty == false)
        #expect(reply?.content != "one two three four five")
    }
}
