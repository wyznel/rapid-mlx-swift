import Foundation

// MARK: - Chat Message
public struct ChatMessage: Codable, Sendable, Equatable {
    public let role: Role
    public let content: String

    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}

// MARK: - Chat Completion Response
public struct ChatCompletionResponse: Codable, Sendable, Equatable {
    public let choices: [ChatChoice]

    public init(choices: [ChatChoice]) {
        self.choices = choices
    }
}

// MARK: - Chat Completion Request
public struct ChatCompletionRequest: Codable, Sendable, Equatable {
    public let model: String
    public let messages: [ChatMessage]

    public init(
        model: String = "default",
        messages: [ChatMessage]
    ) {
        self.model = model
        self.messages = messages
    }
}

// MARK: - Chat Choice
public struct ChatChoice: Codable, Sendable, Equatable {
    public let index: Int?
    public let message: ChatMessage
    public let finishReason: String?

    public init(
        index: Int? = nil,
        message: ChatMessage,
        finishReason: String? = nil
    ) {
        self.index = index
        self.message = message
        self.finishReason = finishReason
    }

    enum CodingKeys: String, CodingKey {
        case index
        case message
        case finishReason = "finish_reason"
    }
}

