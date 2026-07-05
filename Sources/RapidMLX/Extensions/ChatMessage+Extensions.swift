//
//  ChatMessage+Extensions.swift
//  rapid-mlx-swift
//
//  Created by Ben Herbert on 03/07/2026.
//

import Foundation

public extension ChatMessage {
    enum Role: String, Codable, Sendable {
        case system
        case user
        case assistant
        case tool
    }
    
    static func system(_ content: String) -> ChatMessage {
        ChatMessage(role: .system, content: content)
    }
    
    static func user(_ content: String) -> ChatMessage {
        ChatMessage(role: .user, content: content)
    }
    
    static func assistant(_ content: String) -> ChatMessage {
        ChatMessage(role: .assistant, content: content)
    }

    /// Creates a tool-result message to return function output to the model.
    ///
    /// - Parameters:
    ///   - callId: The `id` from the ``ToolCall`` this result corresponds to.
    ///   - content: The function's result, typically JSON-encoded.
    static func toolResult(callId: String, content: String) -> ChatMessage {
        ChatMessage(role: .tool, content: content, toolCallId: callId)
    }
}
