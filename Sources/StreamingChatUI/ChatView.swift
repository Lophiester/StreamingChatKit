import SwiftUI
import StreamingChatCore

/// A ready to use chat screen. Pass a `ChatViewModel` with any `ChatStreamingService`.
public struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    @FocusState private var inputIsFocused: Bool

    private let bottomID = "chat-bottom"

    public init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            messageList
            if let error = viewModel.errorMessage {
                ErrorBanner(message: error, retry: { viewModel.retry() })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            inputBar
        }
        .animation(.spring(duration: 0.35), value: viewModel.errorMessage)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        if message.role != .system && !message.content.isEmpty {
                            MessageBubble(message: message)
                                .transition(.asymmetric(
                                    insertion: .move(edge: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                ))
                        }
                    }
                    if viewModel.isWaitingForFirstToken {
                        HStack {
                            TypingIndicator()
                            Spacer(minLength: 48)
                        }
                        .transition(.opacity)
                    }
                    Color.clear
                        .frame(height: 1)
                        .id(bottomID)
                }
                .padding()
                .animation(.spring(duration: 0.3), value: viewModel.messages.count)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.last?.content) { _, _ in
                proxy.scrollTo(bottomID, anchor: .bottom)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.25)) {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message", text: $viewModel.draft, axis: .vertical)
                .lineLimit(1...5)
                .focused($inputIsFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .onSubmit { viewModel.send() }

            if viewModel.isStreaming {
                CircleButton(systemImage: "stop.fill", label: "Stop", action: { viewModel.stop() })
                    .transition(.scale.combined(with: .opacity))
            } else {
                CircleButton(systemImage: "arrow.up", label: "Send", action: { viewModel.send() })
                    .disabled(!viewModel.canSend)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .animation(.spring(duration: 0.25), value: viewModel.isStreaming)
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 48) }
            Text(formatted)
                .textSelection(.enabled)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(isUser ? Color.white : Color.primary)
                .background(
                    isUser ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary),
                    in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                )
                .accessibilityLabel(isUser ? "You said: \(message.content)" : "Assistant said: \(message.content)")
            if !isUser { Spacer(minLength: 48) }
        }
    }

    /// Shows simple markdown (bold, italic, code) while the text is still streaming.
    private var formatted: AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: message.content, options: options)) ?? AttributedString(message.content)
    }
}

struct TypingIndicator: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .frame(width: 7, height: 7)
                    .scaleEffect(isAnimating ? 1 : 0.6)
                    .opacity(isAnimating ? 1 : 0.35)
                    .animation(
                        .easeInOut(duration: 0.55)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.18),
                        value: isAnimating
                    )
            }
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onAppear { isAnimating = true }
        .accessibilityLabel("Assistant is typing")
    }
}

struct CircleButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.accentColor, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct ErrorBanner: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Retry", action: retry)
                .font(.footnote.bold())
        }
        .padding(12)
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal)
    }
}

#if DEBUG
private struct PreviewError: LocalizedError {
    var errorDescription: String? { "The server returned an error. (CHAT-HTTP-500)" }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView(viewModel: ChatViewModel(service: MockChatService()))
            .previewDisplayName("Streaming")
        ChatView(viewModel: ChatViewModel(service: MockChatService(failure: PreviewError())))
            .previewDisplayName("Error")
    }
}
#endif
