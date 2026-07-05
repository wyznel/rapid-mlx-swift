import Foundation

// MARK: - Chat Message
public struct ChatMessage: Codable, Sendable, Equatable {
    public let role: Role
    public let content: String?
    public let toolCalls: [ToolCall]?
    public let toolCallId: String?

    public init(
        role: Role,
        content: String? = nil,
        toolCalls: [ToolCall]? = nil,
        toolCallId: String? = nil
    ) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
    }

    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
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
    public let stream: Bool?
    public let tools: [Tool]?
    public let toolChoice: ToolChoice?
    public let parallelToolCalls: Bool?

    public init(
        model: String = "default",
        messages: [ChatMessage],
        stream: Bool? = nil,
        tools: [Tool]? = nil,
        toolChoice: ToolChoice? = nil,
        parallelToolCalls: Bool? = nil
    ) {
        self.model = model
        self.messages = messages
        self.stream = stream
        self.tools = tools
        self.toolChoice = toolChoice
        self.parallelToolCalls = parallelToolCalls
    }

    enum CodingKeys: String, CodingKey {
        case model, messages, stream, tools
        case toolChoice = "tool_choice"
        case parallelToolCalls = "parallel_tool_calls"
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

// MARK: - Streaming

public struct ChatCompletionChunkDelta: Codable, Sendable, Equatable {
    public let role: ChatMessage.Role?
    public let content: String?
    public let toolCalls: [ToolCallChunkDelta]?

    public init(
        role: ChatMessage.Role? = nil,
        content: String? = nil,
        toolCalls: [ToolCallChunkDelta]? = nil
    ) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
    }

    enum CodingKeys: String, CodingKey {
        case role, content
        case toolCalls = "tool_calls"
    }
}

public struct ChatCompletionChunkChoice: Codable, Sendable, Equatable {
    public let index: Int
    public let delta: ChatCompletionChunkDelta
    public let finishReason: String?

    public init(index: Int, delta: ChatCompletionChunkDelta, finishReason: String? = nil) {
        self.index = index
        self.delta = delta
        self.finishReason = finishReason
    }

    enum CodingKeys: String, CodingKey {
        case index, delta
        case finishReason = "finish_reason"
    }
}

public struct ChatCompletionChunk: Codable, Sendable, Equatable {
    public let id: String
    public let object: String
    public let created: Int
    public let model: String
    public let choices: [ChatCompletionChunkChoice]

    public init(
        id: String,
        object: String,
        created: Int,
        model: String,
        choices: [ChatCompletionChunkChoice]
    ) {
        self.id = id
        self.object = object
        self.created = created
        self.model = model
        self.choices = choices
    }
}
