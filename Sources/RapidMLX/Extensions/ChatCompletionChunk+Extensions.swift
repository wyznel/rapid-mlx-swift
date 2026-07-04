//
//  ChatCompletionChunk+Extensions.swift
//  rapid-mlx-swift
//
//  Created by Ben Herbert on 04/07/2026.
//

public extension ChatCompletionChunk {
    /// The content token from the first choice's delta, if present.
    var firstContentToken: String? {
        choices.first?.delta.content
    }

    /// Whether this chunk signals the end of generation.
    var isFinished: Bool {
        choices.first?.finishReason != nil
    }
}
