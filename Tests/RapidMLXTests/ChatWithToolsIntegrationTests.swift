import Testing
import Foundation
@testable import RapidMLX

// MARK: - ChatStreamEvents & ChatWithTools Integration Tests (Require Live Server)

struct ChatWithToolsIntegrationTests {

    struct WeatherInput: Codable {
        let location: String
    }
    struct WeatherOutput: Codable {
        let temperature: Int
        let condition: String
        let unit: String
    }

    /// A simple weather tool definition reused across tests.
    private static let weatherTool = Tool<WeatherInput, WeatherOutput>(
        name: "get_weather",
        description: "Get the current weather for a location",
        parameters: [
            "type": "object",
            "properties": [
                "location": [
                    "type": "string",
                    "description": "The city name"
                ]
            ],
            "required": ["location"]
        ]
    ) { input async throws -> WeatherOutput in
        return WeatherOutput(temperature: 18, condition: "partly cloudy", unit: "celsius")
    }

    // MARK: - chatStreamEvents Tests

    @Test("chatStreamEvents with tools returns .toolCallsReady and .finished events")
    func streamEventsWithToolCalls() async throws {
        let client = RapidMLXClient()
        let requestTools = try [Self.weatherTool].toChatCompletionTools()
        let request = ChatCompletionRequest(
            messages: [.user("What is the weather in London?")],
            tools: requestTools,
            toolChoice: .required
        )

        var receivedToolCallsReady = false
        var receivedFinished = false
        var toolCalls: [ToolCall] = []

        for try await event in client.chatStreamEvents(request) {
            switch event {
            case .content:
                break
            case .toolCallsReady(let calls):
                receivedToolCallsReady = true
                toolCalls = calls
            case .finished(let message):
                receivedFinished = true
                // The finished message should contain tool calls since we forced them
                #expect(message.toolCalls != nil)
            }
        }

        #expect(receivedToolCallsReady)
        #expect(receivedFinished)
        #expect(!toolCalls.isEmpty)
        #expect(toolCalls[0].function.name == "get_weather")
    }

    @Test("chatStreamEvents without tools yields .content and .finished only")
    func streamEventsWithoutTools() async throws {
        let client = RapidMLXClient()
        let request = ChatCompletionRequest(
            messages: [.user("Say hello in 3 words")]
        )

        var contentTokens: [String] = []
        var receivedToolCallsReady = false
        var receivedFinished = false
        var finishedMessage: ChatMessage?

        for try await event in client.chatStreamEvents(request) {
            switch event {
            case .content(let token):
                contentTokens.append(token)
            case .toolCallsReady:
                receivedToolCallsReady = true
            case .finished(let message):
                receivedFinished = true
                finishedMessage = message
            }
        }

        #expect(!contentTokens.isEmpty)
        #expect(!receivedToolCallsReady)
        #expect(receivedFinished)

        let msg = try #require(finishedMessage)
        #expect(msg.role == .assistant)
        let text = try #require(msg.content)
        #expect(!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(msg.toolCalls == nil)
    }

    // MARK: - chatWithTools Streaming Tests

    @Test("chatWithTools streaming completes a full tool round-trip")
    func streamingToolRoundTrip() async throws {
        let client = RapidMLXClient()
        var contentTokens: [String] = []
        var receivedToolCallsReady = false
        var receivedFinished = false
        var finishedMessage: ChatMessage?

        let stream: AsyncThrowingStream<ChatStreamEvent, Error> = try client.chatWithTools(
            messages: [.user("What is the weather in London?")],
            tools: [Self.weatherTool]
        )

        for try await event in stream {
            switch event {
            case .content(let token):
                contentTokens.append(token)
            case .toolCallsReady:
                receivedToolCallsReady = true
            case .finished(let message):
                receivedFinished = true
                finishedMessage = message
            }
        }

        #expect(receivedToolCallsReady)
        #expect(receivedFinished)

        // The final message should be a text response (after tool execution)
        let msg = try #require(finishedMessage)
        #expect(msg.role == .assistant)
        let finalText = try #require(msg.content)
        #expect(!finalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        // The final response should not have tool calls (model should produce text after seeing results)
        #expect(msg.toolCalls == nil)
    }

    // MARK: - chatWithTools Non-Streaming Tests

    @Test("chatWithTools non-streaming completes a full tool round-trip")
    func nonStreamingToolRoundTrip() async throws {
        let client = RapidMLXClient()
        let response: ChatCompletionResponse = try await client.chatWithTools(
            messages: [.user("What is the weather in London?")],
            tools: [Self.weatherTool]
        )

        // The final response should be a text reply, not another tool call
        let text = try #require(response.firstText)
        #expect(!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        #expect(!response.hasToolCalls)
    }

    // MARK: - chatWithTools Convenience Overload Tests

    @Test("chatWithTools convenience overload completes streaming round-trip")
    func convenienceStreamingRoundTrip() async throws {
        let client = RapidMLXClient()

        var receivedFinished = false

        let stream: AsyncThrowingStream<ChatStreamEvent, Swift.Error> = try client.chatWithTools(
            messages: [.user("What is the weather in London?")],
            tools: [Self.weatherTool],
            toolChoice: .auto
        )

        for try await event in stream {
            if case .finished(let msg) = event {
                receivedFinished = true
                #expect(msg.role == .assistant)
            }
        }

        #expect(receivedFinished)
    }
}
