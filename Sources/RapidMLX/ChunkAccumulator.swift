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
struct ChunkAccumulator: Sendable {
    var role: ChatMessage.Role = .assistant
    private var contentFragments: [String] = []
    
    private var toolCallBuilders: [Int: ToolCallBuilder] = [:]
    
    init() {}
    
    /// Appends a streaming chunk to the accumulated state.
    mutating func append(_ chunk: ChatCompletionChunk) {
        if let delta = chunk.choices.first?.delta {
            if let role = delta.role {
                self.role = role
            }
            if let content = delta.content {
                contentFragments.append(content)
            }
        }
        
        if let deltas = chunk.firstToolCallDeltas {
            for delta in deltas {
                var builder = toolCallBuilders[delta.index] ?? ToolCallBuilder()
                
                if let id = delta.id {
                    builder.id = id
                }
                if let name = delta.function?.name {
                    builder.nameFragments.append(name)
                }
                if let args = delta.function?.arguments {
                    builder.argumentFragments.append(args)
                }
                
                toolCallBuilders[delta.index] = builder
            }
        }
    }
    
    /// The fully reconstructed assistant message.
    ///
    /// Use this to append the assistant's response to your conversation history
    /// before executing tool calls.
    var message: ChatMessage {
        let content = contentFragments.joined()
        let tools: [ToolCall]?
        if toolCallBuilders.isEmpty {
            tools = nil
        } else {
            let sortedBuilders = toolCallBuilders.sorted(by: { $0.key < $1.key }).map { $0.value }
            tools = sortedBuilders.compactMap { builder in
                let name = builder.nameFragments.joined()
                guard let id = builder.id, !name.isEmpty else { return nil }
                return ToolCall(
                    id: id,
                    function: FunctionCall(
                        name: name,
                        arguments: builder.argumentFragments.joined()
                    )
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
        var nameFragments: [String] = []
        var argumentFragments: [String] = []
    }
}
