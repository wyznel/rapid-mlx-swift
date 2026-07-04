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

// MARK: - Model

public struct Model: Codable, Sendable, Equatable {
    public let id: String
    public let object: String
    public let created: Int
    public let ownedBy: String
    public let recommendedSampling: String?
    public let isHybrid: Bool
    public let isMoe: Bool
    public let toolCallParser: String
    public let reasoningParser: String
    public let modality: String
    public let contextWindow: Int
    public let capabilities: [String]
    public let audioLanes: [String]?

    enum CodingKeys: String, CodingKey {
        case id, object, created, capabilities, modality
        case ownedBy = "owned_by"
        case recommendedSampling = "recommended_sampling"
        case isHybrid = "is_hybrid"
        case isMoe = "is_moe"
        case toolCallParser = "tool_call_parser"
        case reasoningParser = "reasoning_parser"
        case contextWindow = "context_window"
        case audioLanes = "audio_lanes"
    }
}

public struct ListModelResponse: Codable, Sendable, Equatable {
    public let object: String
    public let models: [Model]
    
    enum CodingKeys: String, CodingKey {
        case object
        case models = "data"
    }
}
