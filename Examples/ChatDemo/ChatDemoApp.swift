// A tiny demo app. Create a new iOS app in Xcode, add this package,
// and replace the generated App file with this one.

import SwiftUI
import StreamingChatCore
import StreamingChatUI

@main
struct ChatDemoApp: App {
    @State private var viewModel = ChatViewModel(
        service: MockChatService(),
        messages: [ChatMessage(role: .assistant, content: "Hi! Ask me anything.")]
    )

    // To use a real model, point this to your own backend that adds the API key:
    //
    // @State private var viewModel = ChatViewModel(
    //     service: OpenAICompatibleService(configuration: .init(
    //         baseURL: URL(string: "https://your-backend.example.com/v1")!,
    //         apiKey: "token-from-your-backend",
    //         model: "gpt-4o-mini"
    //     ))
    // )

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                ChatView(viewModel: viewModel)
                    .navigationTitle("Chat")
            }
        }
    }
}
