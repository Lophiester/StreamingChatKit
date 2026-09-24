import Foundation

/// One event from a `text/event-stream` response.
public struct ServerSentEvent: Equatable, Sendable {
    public var event: String?
    public var data: String
    public var id: String?

    public init(event: String? = nil, data: String, id: String? = nil) {
        self.event = event
        self.data = data
        self.id = id
    }
}

/// A small parser that follows the Server-Sent Events format.
///
/// Feed it one line at a time. An empty line closes the current event.
/// Lines that start with `:` are comments and are ignored.
public struct SSEParser: Sendable {
    private var event: String?
    private var id: String?
    private var dataLines: [String] = []

    public init() {}

    /// Returns an event when `line` closes one, otherwise `nil`.
    public mutating func feed(line: String) -> ServerSentEvent? {
        if line.isEmpty {
            return flush()
        }
        if line.hasPrefix(":") {
            return nil
        }

        let field: Substring
        var value: Substring
        if let colon = line.firstIndex(of: ":") {
            field = line[..<colon]
            value = line[line.index(after: colon)...]
            if value.first == " " {
                value = value.dropFirst()
            }
        } else {
            field = Substring(line)
            value = ""
        }

        switch field {
        case "data":
            dataLines.append(String(value))
        case "event":
            event = String(value)
        case "id":
            id = String(value)
        default:
            break
        }
        return nil
    }

    /// Closes the current event, if there is one. Call it when the stream ends.
    public mutating func flush() -> ServerSentEvent? {
        defer {
            event = nil
            dataLines.removeAll()
        }
        guard !dataLines.isEmpty else { return nil }
        return ServerSentEvent(event: event, data: dataLines.joined(separator: "\n"), id: id)
    }
}

/// Splits a byte stream into lines and keeps the empty ones.
///
/// `URLSession.AsyncBytes.lines` skips empty lines, but SSE needs them
/// to know where an event ends. This splitter handles `\n`, `\r\n` and `\r`.
public struct SSELineSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == UInt8 {
    public typealias Element = String

    let base: Base

    public struct AsyncIterator: AsyncIteratorProtocol {
        var iterator: Base.AsyncIterator
        var buffer: [UInt8] = []
        var lastByteWasCR = false
        var finished = false

        public mutating func next() async throws -> String? {
            guard !finished else { return nil }

            while let byte = try await iterator.next() {
                switch byte {
                case UInt8(ascii: "\n"):
                    if lastByteWasCR {
                        lastByteWasCR = false
                        continue
                    }
                    return takeLine()
                case UInt8(ascii: "\r"):
                    lastByteWasCR = true
                    return takeLine()
                default:
                    lastByteWasCR = false
                    buffer.append(byte)
                }
            }

            finished = true
            return buffer.isEmpty ? nil : takeLine()
        }

        private mutating func takeLine() -> String {
            let line = String(decoding: buffer, as: UTF8.self)
            buffer.removeAll(keepingCapacity: true)
            return line
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: base.makeAsyncIterator())
    }
}

/// Turns a sequence of lines into a sequence of `ServerSentEvent`.
public struct ServerSentEventSequence<Lines: AsyncSequence>: AsyncSequence where Lines.Element == String {
    public typealias Element = ServerSentEvent

    let lines: Lines

    public struct AsyncIterator: AsyncIteratorProtocol {
        var iterator: Lines.AsyncIterator
        var parser = SSEParser()
        var finished = false

        public mutating func next() async throws -> ServerSentEvent? {
            guard !finished else { return nil }

            while let line = try await iterator.next() {
                if let event = parser.feed(line: line) {
                    return event
                }
            }

            finished = true
            return parser.flush()
        }
    }

    public func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(iterator: lines.makeAsyncIterator())
    }
}

public extension AsyncSequence where Element == UInt8 {
    /// Lines of the stream, including empty lines.
    var sseLines: SSELineSequence<Self> {
        SSELineSequence(base: self)
    }
}

public extension AsyncSequence where Element == String {
    /// Server-Sent Events parsed from these lines.
    var serverSentEvents: ServerSentEventSequence<Self> {
        ServerSentEventSequence(lines: self)
    }
}
