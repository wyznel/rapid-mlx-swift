//
//  ChunkAccumulator.swift
//  rapid-mlx-swift
//
//  Created by Ben Herbert on 03/07/2026.
//


import Foundation

/// Accumulates streaming `ChatCompletionChunk` deltas into a final `ChatMessage`.
///
/// This simplifies handling streamed responses that include tool calls or text by automatically
/// concatenating chunk content and tool call parameters.
public struct ChunkAccumulator: Sendable {
    public var role: ChatMessage.Role = .assistant
    public var content: String = ""
    
    private var toolCallBuilders: [Int: ToolCallBuilder] = [:]
    
    public init() {}
    
    /// Appends a streaming chunk to the accumulated state.
    public mutating func append(_ chunk: ChatCompletionChunk) {
        if let token = chunk.firstContentToken {
            content += token
        }
        
        if let deltas = chunk.firstToolCallDeltas {
            for delta in deltas {
                var builder = toolCallBuilders[delta.index] ?? ToolCallBuilder()
                
                if let id = delta.id {
                    builder.id = id
                }
                if let name = delta.function?.name {
                    builder.name += name
                }
                if let args = delta.function?.arguments {
                    builder.arguments += args
                }
                
                toolCallBuilders[delta.index] = builder
            }
        }
    }
    
    /// The fully reconstructed assistant message.
    ///
    /// Use this to append the assistant's response to your conversation history
    /// before executing tool calls.
    public var message: ChatMessage {
        let tools: [ToolCall]?
        if toolCallBuilders.isEmpty {
            tools = nil
        } else {
            let sortedBuilders = toolCallBuilders.sorted(by: { $0.key < $1.key }).map { $0.value }
            tools = sortedBuilders.compactMap { builder in
                guard let id = builder.id, !builder.name.isEmpty else { return nil }
                return ToolCall(
                    id: id,
                    function: FunctionCall(name: builder.name, arguments: builder.arguments)
                )
            }
        }
        
        return ChatMessage(
            role: role,
            content: content.isEmpty ? nil : content,
            toolCalls: tools
        )
    }
    
    private struct ToolCallBuilder: Sendable {
        var id: String?
        var name: String = ""
        var arguments: String = ""
    }
}
