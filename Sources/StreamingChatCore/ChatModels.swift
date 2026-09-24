import Foundation

public struct ChatMessage: Identifiable, Equatable, Sendable, Codable {
    public enum Role: String, Codable, Sendable {
        case system
        case user
        case assistant
    }

    public let id: UUID
    public var role: Role
    public var content: String

    public init(id: UUID = UUID(), role: Role, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

/// Errors carry a short code, so a user can report it and a developer can find it in the logs.
public enum ChatError: Error, Equatable, LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case emptyReply

    public var code: String {
        switch self {
        case .invalidResponse: return "CHAT-001"
        case .httpStatus(let status): return "CHAT-HTTP-\(status)"
        case .emptyReply: return "CHAT-002"
        }
    }

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The server sent a response we could not read. (\(code))"
        case .httpStatus:
            return "The server returned an error. (\(code))"
        case .emptyReply:
            return "The assistant did not send any text. (\(code))"
        }
    }
}

/// Anything that can stream a reply, token by token.
public protocol ChatStreamingService: Sendable {
    func streamReply(for messages: [ChatMessage]) -> AsyncThrowingStream<String, Error>
}
