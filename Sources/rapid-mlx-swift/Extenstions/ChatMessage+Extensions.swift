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
    
}
