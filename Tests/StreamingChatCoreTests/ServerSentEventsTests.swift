import Testing
@testable import StreamingChatCore

/// Turns an array into an async sequence, so we can test the parsers without a network.
private func asyncSequence<T: Sendable>(_ values: [T]) -> AsyncStream<T> {
    AsyncStream { continuation in
        for value in values { continuation.yield(value) }
        continuation.finish()
    }
}

private func bytes(_ text: String) -> AsyncStream<UInt8> {
    asyncSequence(Array(text.utf8))
}

@Suite("SSE parser")
struct SSEParserTests {
    @Test func parsesASingleEvent() {
        var parser = SSEParser()
        let first = parser.feed(line: "data: hello")
        let second = parser.feed(line: "")
        #expect(first == nil)
        #expect(second == ServerSentEvent(data: "hello"))
    }

    @Test func joinsMultipleDataLines() {
        var parser = SSEParser()
        _ = parser.feed(line: "data: first")
        _ = parser.feed(line: "data: second")
        let event = parser.feed(line: "")
        #expect(event == ServerSentEvent(data: "first\nsecond"))
    }

    @Test func readsEventNameAndID() {
        var parser = SSEParser()
        _ = parser.feed(line: "event: message")
        _ = parser.feed(line: "id: 42")
        _ = parser.feed(line: "data:no space")
        let event = parser.feed(line: "")
        #expect(event == ServerSentEvent(event: "message", data: "no space", id: "42"))
    }

    @Test func ignoresComments() {
        var parser = SSEParser()
        let comment = parser.feed(line: ": keep-alive")
        let end = parser.feed(line: "")
        #expect(comment == nil)
        #expect(end == nil)
    }

    @Test func flushReturnsTheLastEvent() {
        var parser = SSEParser()
        _ = parser.feed(line: "data: tail")
        let first = parser.flush()
        let second = parser.flush()
        #expect(first == ServerSentEvent(data: "tail"))
        #expect(second == nil)
    }
}

@Suite("Line splitter")
struct SSELineSequenceTests {
    @Test(arguments: ["a\nb\n\nc", "a\r\nb\r\n\r\nc", "a\rb\r\rc"])
    func keepsEmptyLines(input: String) async throws {
        var lines: [String] = []
        for try await line in bytes(input).sseLines {
            lines.append(line)
        }
        #expect(lines == ["a", "b", "", "c"])
    }

    @Test func keepsMultiByteCharacters() async throws {
        var lines: [String] = []
        for try await line in bytes("olá 👋\nこんにちは\n").sseLines {
            lines.append(line)
        }
        #expect(lines == ["olá 👋", "こんにちは"])
    }
}

@Suite("OpenAI stream")
struct OpenAIStreamTests {
    private let stream = """
    data: {"choices":[{"delta":{"role":"assistant"}}]}

    data: {"choices":[{"delta":{"content":"Hello"}}]}

    : keep-alive

    data: {"choices":[{"delta":{"content":" world"}}]}

    data: [DONE]


    """

    @Test func decodesTokensFromAFullStream() async throws {
        var tokens: [String] = []
        for try await event in bytes(stream).sseLines.serverSentEvents {
            if event.data == "[DONE]" { break }
            if let token = try OpenAIChunkDecoder.token(from: event.data) {
                tokens.append(token)
            }
        }
        #expect(tokens == ["Hello", " world"])
    }

    @Test func roleOnlyChunkHasNoToken() throws {
        let token = try OpenAIChunkDecoder.token(from: #"{"choices":[{"delta":{"role":"assistant"}}]}"#)
        #expect(token == nil)
    }

    @Test func invalidJSONThrows() {
        #expect(throws: (any Error).self) {
            try OpenAIChunkDecoder.token(from: "not json")
        }
    }
}
