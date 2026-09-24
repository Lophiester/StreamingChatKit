<div align="center">

# StreamingChatKit

**A small SwiftUI package for AI chat that streams the answer word by word.**

[![CI](https://github.com/Lophiester/StreamingChatKit/actions/workflows/ci.yml/badge.svg)](https://github.com/Lophiester/StreamingChatKit/actions/workflows/ci.yml)
![Swift](https://img.shields.io/badge/Swift-5.10%2B-F05138?logo=swift&logoColor=white)
![Platforms](https://img.shields.io/badge/iOS%2017%20%7C%20macOS%2014-000000?logo=apple&logoColor=white)
![SPM](https://img.shields.io/badge/SPM-compatible-brightgreen)
![License](https://img.shields.io/badge/license-MIT-blue)

</div>

---

I built AI chat features in production apps, and the same problems show up every time: parsing the stream, keeping the UI smooth while text arrives, handling errors, and letting the user stop the answer. This package is my clean, open version of that work, written from scratch.

## Features

- **Real streaming** with `URLSession.bytes` and `async/await`. Text shows up while the model is still writing.
- **Spec compliant SSE parser.** `URLSession.AsyncBytes.lines` drops empty lines, and SSE needs them to know where an event ends. The package has its own line splitter that keeps them.
- **Works with any OpenAI compatible API** (OpenAI, Groq, OpenRouter, a local server, or your own backend).
- **MVVM with `@Observable`.** All the logic lives in `ChatViewModel`, so it is tested without any UI.
- **Stop and retry.** Stopping keeps the partial answer. Errors show a short code (like `CHAT-HTTP-500`) that users can report.
- **Ready to use SwiftUI screen** with an animated typing indicator, auto scroll, inline markdown and accessibility labels.
- **Mock service** for SwiftUI previews and tests.
- **Tested with Swift Testing** and checked on every push by GitHub Actions.

## How it works

```mermaid
flowchart LR
    V[ChatView<br/>SwiftUI] -- send / stop / retry --> VM[ChatViewModel<br/>@MainActor @Observable]
    VM -- messages --> V
    VM -- history --> S{{ChatStreamingService}}
    S --> O[OpenAICompatibleService]
    S --> M[MockChatService]
    O -- URLSession.bytes --> L[SSELineSequence]
    L --> P[ServerSentEventSequence]
    P -- tokens --> VM
```

1. The view calls `send()`. The view model adds the user message and an empty assistant message.
2. The service opens a stream. Bytes become lines, lines become events, events become tokens.
3. Each token is added to the assistant message, and SwiftUI updates the bubble.
4. When the stream ends, fails or is stopped, the view model cleans up. Empty replies are removed, and errors become a readable message.

## Installation

In Xcode, go to **File > Add Package Dependencies** and paste:

```
https://github.com/Lophiester/StreamingChatKit
```

Or add it to `Package.swift`:

```swift
.package(url: "https://github.com/Lophiester/StreamingChatKit", branch: "main")
```

## Usage

```swift
import SwiftUI
import StreamingChatCore
import StreamingChatUI

struct ContentView: View {
    @State private var viewModel = ChatViewModel(service: MockChatService())

    var body: some View {
        ChatView(viewModel: viewModel)
    }
}
```

With a real model:

```swift
let service = OpenAICompatibleService(configuration: .init(
    baseURL: URL(string: "https://your-backend.example.com/v1")!,
    apiKey: "token-from-your-backend",
    model: "gpt-4o-mini"
))
let viewModel = ChatViewModel(service: service)
```

> **Tip:** do not ship an API key inside your app. Point `baseURL` to your own backend (for example a Cloud Function) that adds the key on the server.

Want only the logic and your own UI? Import `StreamingChatCore` and use `ChatViewModel` or the parsers directly:

```swift
for try await event in bytes.sseLines.serverSentEvents {
    print(event.data)
}
```

## Project structure

```
Sources/
├── StreamingChatCore/
│   ├── ServerSentEvents.swift        # SSE parser, line splitter, async sequences
│   ├── OpenAICompatibleService.swift # Streaming client and chunk decoder
│   ├── ChatViewModel.swift           # State, send, stop, retry
│   ├── ChatModels.swift              # ChatMessage, ChatError, service protocol
│   └── MockChatService.swift         # Fake service for previews and tests
└── StreamingChatUI/
    └── ChatView.swift                # Chat screen, bubbles, typing indicator
Tests/
└── StreamingChatCoreTests/           # Swift Testing suites
```

## Running the tests

```bash
swift test
```

The tests cover the SSE parser (multi line data, comments, `\r\n` and `\r` line endings, emoji and Japanese text), a full OpenAI style stream, and the view model (sending, errors, retry and stop).

## Example app

See [`Examples/ChatDemo`](Examples/ChatDemo/ChatDemoApp.swift) for a one file demo app.

## License

MIT. See [LICENSE](LICENSE).

---

<div align="center">

Made by [Charles Yamamoto](https://github.com/Lophiester) · [yamaflare.com](https://yamaflare.com)

</div>
