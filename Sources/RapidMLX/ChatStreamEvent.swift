//
//  ChatStreamEvent.swift
//  rapid-mlx-swift
//
//  Created by Ben Herbert on 06/07/2026.
//

import Foundation

/// High-level events emitted during a streaming chat completion.
///
/// Use with ``RapidMLXClient/chatStreamEvents(_:)-swift.method`` to consume
/// streaming responses without manually accumulating tool call deltas.
///
/// ```swift
/// for try await event in client.chatStreamEvents(request) {
///     switch event {
///     case .content(let token):
///         print(token, terminator: "")
///     case .toolCallsReady(let calls):
///         // execute tool calls
///     case .finished(let message):
///         history.append(message)
///     }
/// }
/// ```
public enum ChatStreamEvent: Sendable {
    /// A content token arrived (text fragment from the assistant).
    case content(String)

    /// All tool calls have been fully assembled from streaming deltas.
    /// Fired once when `finish_reason` is `tool_calls`.
    case toolCallsReady([ToolCall])

    /// The stream finished. Contains the complete reconstructed assistant message
    /// (with content and/or tool calls) suitable for appending to conversation history.
    case finished(ChatMessage)
}
