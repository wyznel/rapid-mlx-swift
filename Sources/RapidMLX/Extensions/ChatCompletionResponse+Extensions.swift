//
//  ChatCompletionResponse+Extensions.swift
//  rapid-mlx-swift
//
//  Created by Ben Herbert on 03/07/2026.
//

public extension ChatCompletionResponse {
    var firstMessage: ChatMessage? {
        choices.first?.message
    }
    
    var firstText: String? {
        firstMessage?.content
    }

    /// The tool calls from the first choice, if present.
    var firstToolCalls: [ToolCall]? {
        firstMessage?.toolCalls
    }

    /// Whether the first choice contains tool calls.
    var hasToolCalls: Bool {
        !(firstToolCalls?.isEmpty ?? true)
    }
}
