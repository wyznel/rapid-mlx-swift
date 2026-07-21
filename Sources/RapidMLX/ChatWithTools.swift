//
//  ChatWithTools.swift
//  rapid-mlx-swift
//
//  Created by Ben Herbert on 06/07/2026.
//

import Foundation

extension RapidMLXClient {

    // MARK: - Streaming tool execution loop

    /// Streams a chat completion with automatic tool execution.
    ///
    /// This method handles the full tool-calling lifecycle:
    /// 1. Sends the initial request and streams content tokens
    /// 2. When the model requests tool calls, executes them via the tool's implementation
    /// 3. Sends tool results back and streams the follow-up response
    /// 4. Repeats if the model requests more tool calls (up to `maxRounds`)
    ///
    /// Content tokens from every round are yielded as ``ChatStreamEvent/content(_:)`` events.
    /// The final ``ChatStreamEvent/finished(_:)`` event contains the last assistant message.
    ///
    /// - Parameters:
    ///   - body: The initial chat completion request (should include tools).
    ///   - tools: The tools to execute.
    ///   - maxRounds: Maximum number of tool-calling round-trips. Default is 10.
    /// - Returns: A stream of ``ChatStreamEvent`` values.
    private nonisolated func chatWithTools(
        _ body: ChatCompletionRequest,
        tools: [any ToolProtocol],
        maxRounds: Int = 10
    ) -> AsyncThrowingStream<ChatStreamEvent, Swift.Error> {
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
                                guard let executableTool = tools.compactMap({ $0 as? ExecutableTool }).first(where: { $0.name == toolCall.function.name }) else {
                                    throw RapidMLXError.toolCallError("Unknown tool called by model: \(toolCall.function.name)")
                                }
                                let result = try await executableTool.execute(arguments: toolCall.function.arguments)
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

    /// Convenience overload that builds a ``ChatCompletionRequest`` for you and automatically executes tools.
    public nonisolated func chatWithTools(
        messages: [ChatMessage],
        model: String = "default",
        tools: [any ToolProtocol],
        toolChoice: ToolChoice? = .auto,
        parallelToolCalls: Bool? = nil,
        maxRounds: Int = 10
    ) throws -> AsyncThrowingStream<ChatStreamEvent, Swift.Error> {
        let requestTools = try tools.toChatCompletionTools()
        
        let request = ChatCompletionRequest(
            model: model,
            messages: messages,
            tools: requestTools,
            toolChoice: toolChoice,
            parallelToolCalls: parallelToolCalls
        )
        return chatWithTools(request, tools: tools, maxRounds: maxRounds)
    }

    // MARK: - Non-streaming tool execution loop

    /// Executes a chat completion with automatic tool calling, returning the final response.
    ///
    /// Uses the non-streaming ``chat(_:)`` method internally. Loops up to `maxRounds`
    /// times if the model keeps requesting tool calls.
    ///
    /// - Parameters:
    ///   - body: The initial chat completion request (should include tools).
    ///   - tools: The tools to execute.
    ///   - maxRounds: Maximum number of tool-calling round-trips. Default is 10.
    /// - Returns: The final ``ChatCompletionResponse`` after all tool calls are resolved.
    private func chatWithTools(
        _ body: ChatCompletionRequest,
        tools: [any ToolProtocol],
        maxRounds: Int = 10
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
                    guard let executableTool = tools.compactMap({ $0 as? ExecutableTool }).first(where: { $0.name == toolCall.function.name }) else {
                        throw RapidMLXError.toolCallError("Unknown tool called by model: \(toolCall.function.name)")
                    }
                    let result = try await executableTool.execute(arguments: toolCall.function.arguments)
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

    /// Convenience overload that builds a ``ChatCompletionRequest`` for you and automatically executes tools.
    public func chatWithTools(
        messages: [ChatMessage],
        model: String = "default",
        tools: [any ToolProtocol],
        toolChoice: ToolChoice? = .auto,
        parallelToolCalls: Bool? = nil,
        maxRounds: Int = 10
    ) async throws -> ChatCompletionResponse {
        let requestTools = try tools.toChatCompletionTools()
        
        let request = ChatCompletionRequest(
            model: model,
            messages: messages,
            tools: requestTools,
            toolChoice: toolChoice,
            parallelToolCalls: parallelToolCalls
        )
        
        return try await chatWithTools(request, tools: tools, maxRounds: maxRounds)
    }
}
