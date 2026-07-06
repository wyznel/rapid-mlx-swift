//
//  ChatWithTools.swift
//  rapid-mlx-swift
//
//  Created by Ben Herbert on 06/07/2026.
//

import Foundation

/// A closure that executes a tool call and returns the result as a JSON string.
public typealias ToolHandler = @Sendable (ToolCall) async throws -> String

extension RapidMLXClient {

    // MARK: - Streaming tool execution loop

    /// Streams a chat completion with automatic tool execution.
    ///
    /// This method handles the full tool-calling lifecycle:
    /// 1. Sends the initial request and streams content tokens
    /// 2. When the model requests tool calls, executes them via `handler`
    /// 3. Sends tool results back and streams the follow-up response
    /// 4. Repeats if the model requests more tool calls (up to `maxRounds`)
    ///
    /// Content tokens from every round are yielded as ``ChatStreamEvent/content(_:)`` events.
    /// The final ``ChatStreamEvent/finished(_:)`` event contains the last assistant message.
    ///
    /// ```swift
    /// for try await event in client.chatWithTools(
    ///     messages: [.user("What's the weather in London?")],
    ///     tools: [weatherTool],
    ///     handler: { call in
    ///         try await fetchWeather(call)
    ///     }
    /// ) {
    ///     switch event {
    ///     case .content(let token): print(token, terminator: "")
    ///     case .toolCallsReady: print("[calling tools...]")
    ///     case .finished(let msg): history.append(msg)
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - body: The initial chat completion request (should include tools).
    ///   - maxRounds: Maximum number of tool-calling round-trips. Default is 10.
    ///   - handler: Closure that executes a ``ToolCall`` and returns a JSON result string.
    /// - Returns: A stream of ``ChatStreamEvent`` values.
    public func chatWithTools(
        _ body: ChatCompletionRequest,
        maxRounds: Int = 10,
        handler: @escaping ToolHandler
    ) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        let capturedSelf = self

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var messages = body.messages

                    for _ in 0..<maxRounds {
                        let request = ChatCompletionRequest(
                            model: body.model,
                            messages: messages,
                            tools: body.tools,
                            toolChoice: body.toolChoice,
                            parallelToolCalls: body.parallelToolCalls
                        )

                        var assistantMessage: ChatMessage?

                        for try await event in capturedSelf.chatStreamEvents(request) {
                            switch event {
                            case .content(let token):
                                continuation.yield(.content(token))

                            case .toolCallsReady(let calls):
                                continuation.yield(.toolCallsReady(calls))

                            case .finished(let message):
                                assistantMessage = message
                            }
                        }

                        guard let message = assistantMessage else {
                            break
                        }

                        guard let toolCalls = message.toolCalls, !toolCalls.isEmpty else {
                            // No tool calls -- this is the final text response.
                            continuation.yield(.finished(message))
                            continuation.finish()
                            return
                        }

                        // Append the assistant message (with tool calls) to history.
                        messages.append(message)

                        // Execute each tool call and append results.
                        for toolCall in toolCalls {
                            do {
                                let result = try await handler(toolCall)
                                messages.append(
                                    .toolResult(callId: toolCall.id, content: result)
                                )
                            } catch {
                                let errorJSON = "{\"error\": \"\(String(describing: error).replacingOccurrences(of: "\"", with: "\\\""))\"}"
                                messages.append(
                                    .toolResult(callId: toolCall.id, content: errorJSON)
                                )
                            }
                        }

                        // Loop continues: next round will send tool results to the model.
                    }

                    // maxRounds exhausted -- finish with whatever we have.
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    /// Convenience overload that builds a ``ChatCompletionRequest`` for you.
    public func chatWithTools(
        messages: [ChatMessage],
        model: String = "default",
        tools: [Tool],
        toolChoice: ToolChoice? = .auto,
        parallelToolCalls: Bool? = nil,
        maxRounds: Int = 10,
        handler: @escaping ToolHandler
    ) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        let request = ChatCompletionRequest(
            model: model,
            messages: messages,
            tools: tools,
            toolChoice: toolChoice,
            parallelToolCalls: parallelToolCalls
        )
        return chatWithTools(request, maxRounds: maxRounds, handler: handler)
    }

    // MARK: - Non-streaming tool execution loop

    /// Executes a chat completion with automatic tool calling, returning the final response.
    ///
    /// Uses the non-streaming ``chat(_:)-2n239`` method internally. Loops up to `maxRounds`
    /// times if the model keeps requesting tool calls.
    ///
    /// ```swift
    /// let response = try await client.chatWithTools(
    ///     request,
    ///     handler: { call in
    ///         try await executeTool(call)
    ///     }
    /// )
    /// print(response.firstText ?? "")
    /// ```
    ///
    /// - Parameters:
    ///   - body: The initial chat completion request (should include tools).
    ///   - maxRounds: Maximum number of tool-calling round-trips. Default is 10.
    ///   - handler: Closure that executes a ``ToolCall`` and returns a JSON result string.
    /// - Returns: The final ``ChatCompletionResponse`` after all tool calls are resolved.
    public func chatWithTools(
        _ body: ChatCompletionRequest,
        maxRounds: Int = 10,
        handler: @escaping ToolHandler
    ) async throws -> ChatCompletionResponse {
        var messages = body.messages

        for _ in 0..<maxRounds {
            let request = ChatCompletionRequest(
                model: body.model,
                messages: messages,
                tools: body.tools,
                toolChoice: body.toolChoice,
                parallelToolCalls: body.parallelToolCalls
            )

            let response = try await chat(request)

            guard let toolCalls = response.firstToolCalls, !toolCalls.isEmpty else {
                return response
            }

            // Append the assistant message (with tool calls) to history.
            if let assistantMessage = response.firstMessage {
                messages.append(assistantMessage)
            }

            // Execute each tool call and append results.
            for toolCall in toolCalls {
                do {
                    let result = try await handler(toolCall)
                    messages.append(
                        .toolResult(callId: toolCall.id, content: result)
                    )
                } catch {
                    let errorJSON = "{\"error\": \"\(String(describing: error).replacingOccurrences(of: "\"", with: "\\\""))\"}"
                    messages.append(
                        .toolResult(callId: toolCall.id, content: errorJSON)
                    )
                }
            }
        }

        // maxRounds exhausted -- make one final call without tools to get a text response.
        let finalRequest = ChatCompletionRequest(
            model: body.model,
            messages: messages
        )
        return try await chat(finalRequest)
    }
}
