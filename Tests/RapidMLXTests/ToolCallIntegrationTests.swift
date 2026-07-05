import Testing
import Foundation
@testable import RapidMLX

// MARK: - Tool Calling Integration Tests (Require Live Server)

struct ToolCallIntegrationTests {

    /// A simple weather tool definition reused across tests.
    private static let weatherTool = Tool(function: FunctionDefinition(
        name: "get_weather",
        description: "Get the current weather for a location",
        parameters: .object([
            "type": "object",
            "properties": .object([
                "location": .object([
                    "type": "string",
                    "description": "The city name"
                ])
            ]),
            "required": .array(["location"])
        ])
    ))

    @Test("Non-streaming tool call returns finish_reason tool_calls")
    func toolCallIntegration() async throws {
        let client = RapidMLXClient()
        let request = ChatCompletionRequest(
            messages: [.user("What is the weather in London?")],
            tools: [Self.weatherTool],
            toolChoice: .required
        )

        let response = try await client.chat(request)
        #expect(response.hasToolCalls)

        let toolCalls = try #require(response.firstToolCalls)
        #expect(!toolCalls.isEmpty)
        #expect(toolCalls[0].function.name == "get_weather")

        let choice = try #require(response.choices.first)
        #expect(choice.finishReason == "tool_calls")
    }

    @Test("Full tool call round-trip: request -> tool call -> tool result -> final text")
    func toolCallRoundTrip() async throws {
        let client = RapidMLXClient()

        // Step 1: Send request with tools
        let request = ChatCompletionRequest(
            messages: [.user("What is the weather in London?")],
            tools: [Self.weatherTool],
            toolChoice: .required
        )

        let response = try await client.chat(request)
        let toolCalls = try #require(response.firstToolCalls)
        let toolCall = try #require(toolCalls.first)
        #expect(toolCall.function.name == "get_weather")

        // Step 2: Build conversation with tool result
        let assistantMsg = try #require(response.firstMessage)
        let toolResult = ChatMessage.toolResult(
            callId: toolCall.id,
            content: "{\"temperature\": 18, \"condition\": \"partly cloudy\"}"
        )

        let followUp = ChatCompletionRequest(
            messages: [
                .user("What is the weather in London?"),
                assistantMsg,
                toolResult
            ],
            tools: [Self.weatherTool]
        )

        // Step 3: Get final text response
        let finalResponse = try await client.chat(followUp)
        let finalText = try #require(finalResponse.firstText)
        #expect(!finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    @Test("Streaming tool call returns deltas and finishes with tool_calls reason")
    func toolCallStreamingIntegration() async throws {
        let client = RapidMLXClient()
        let request = ChatCompletionRequest(
            messages: [.user("What is the weather in London?")],
            tools: [Self.weatherTool],
            toolChoice: .required
        )

        var receivedToolCallDelta = false
        var finishedWithToolCalls = false

        for try await chunk in client.chatStream(request) {
            if let deltas = chunk.firstToolCallDeltas, !deltas.isEmpty {
                receivedToolCallDelta = true
            }
            if chunk.isToolCallFinish {
                finishedWithToolCalls = true
            }
        }

        #expect(receivedToolCallDelta)
        #expect(finishedWithToolCalls)
    }
}
