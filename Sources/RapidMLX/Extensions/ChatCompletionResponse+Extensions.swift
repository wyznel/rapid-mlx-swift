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
}
