//
//  ToolModels.swift
//  rapid-mlx-swift
//
//  Created by Ben Herbert on 03/07/2026.
//

import Foundation

// MARK: - Tool Definition (Request Side)

/// A tool the model may call. Currently only "function" type is supported.
public struct ChatCompletionTool: Codable, Sendable, Equatable {
    public let type: String
    public let function: FunctionDefinition

    public init(type: String = "function", function: FunctionDefinition) {
        self.type = type
        self.function = function
    }
}

/// Schema describing a callable function.
public struct FunctionDefinition: Codable, Sendable, Equatable {
    public let name: String
    public let description: String?
    public let parameters: JSONValue?

    public init(name: String, description: String? = nil, parameters: JSONValue? = nil) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}

// MARK: - Tool Call (Response Side)

/// A tool call emitted by the model in an assistant message.
public struct ToolCall: Codable, Sendable, Equatable {
    public let id: String
    public let type: String
    public let function: FunctionCall

    public init(id: String, type: String = "function", function: FunctionCall) {
        self.id = id
        self.type = type
        self.function = function
    }
}

/// The function name and JSON-encoded arguments string from a tool call.
public struct FunctionCall: Codable, Sendable, Equatable {
    public let name: String
    public let arguments: String

    public init(name: String, arguments: String) {
        self.name = name
        self.arguments = arguments
    }
}

// MARK: - Tool Call Argument Decoding

extension ToolCall {
    /// Decodes the JSON arguments string into a typed Swift struct.
    ///
    /// ```swift
    /// struct WeatherArgs: Decodable { let location: String }
    /// let args: WeatherArgs = try toolCall.decodedArguments()
    /// ```
    ///
    /// - Parameters:
    ///   - type: The `Decodable` type to decode into. Can be inferred from context.
    ///   - decoder: An optional `JSONDecoder` instance. Defaults to a plain `JSONDecoder()`.
    /// - Returns: The decoded value.
    public func decodedArguments<T: Decodable>(
        _ type: T.Type = T.self,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> T {
        guard let data = function.arguments.data(using: .utf8) else {
            throw RapidMLXError.toolCallError("Invalid UTF-8 in tool call arguments")
        }
        return try decoder.decode(type, from: data)
    }
}

// MARK: - Tool Call Chunk (Streaming)

/// A partial tool call delta received during streaming.
public struct ToolCallChunkDelta: Codable, Sendable, Equatable {
    public let index: Int
    public let id: String?
    public let type: String?
    public let function: FunctionCallDelta?

    public init(index: Int, id: String? = nil, type: String? = nil, function: FunctionCallDelta? = nil) {
        self.index = index
        self.id = id
        self.type = type
        self.function = function
    }
}

/// Partial function data in a streaming tool call delta.
public struct FunctionCallDelta: Codable, Sendable, Equatable {
    public let name: String?
    public let arguments: String?

    public init(name: String? = nil, arguments: String? = nil) {
        self.name = name
        self.arguments = arguments
    }
}

// MARK: - Tool Choice

/// Controls how the model selects tools.
///
/// - ``auto``: Model decides whether to call a tool (default).
/// - ``none``: Model must not call any tool.
/// - ``required``: Model must call at least one tool.
/// - ``function(name:)``: Model must call the specified function.
public enum ToolChoice: Sendable, Equatable {
    case auto
    case none
    case required
    case function(name: String)
}

// MARK: - ToolChoice Codable

extension ToolChoice: Codable {
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .auto:
            var container = encoder.singleValueContainer()
            try container.encode("auto")
        case .none:
            var container = encoder.singleValueContainer()
            try container.encode("none")
        case .required:
            var container = encoder.singleValueContainer()
            try container.encode("required")
        case .function(let name):
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode("function", forKey: .type)
            try container.encode(["name": name], forKey: .function)
        }
    }

    public init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let str = try? container.decode(String.self) {
            switch str {
            case "auto": self = .auto
            case "none": self = .none
            case "required": self = .required
            default: self = .auto
            }
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let funcDict = try container.decode([String: String].self, forKey: .function)
        self = .function(name: funcDict["name"] ?? "")
    }

    private enum CodingKeys: String, CodingKey {
        case type, function
    }
}
