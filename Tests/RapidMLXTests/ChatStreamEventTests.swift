import Testing
import Foundation
@testable import RapidMLX

// MARK: - ChatStreamEvent Construction Tests

struct ChatStreamEventTests {

    @Test("ChatStreamEvent.content constructs with a string")
    func contentCase() {
        let event = ChatStreamEvent.content("Hello")
        if case .content(let token) = event {
            #expect(token == "Hello")
        } else {
            Issue.record("Expected .content case")
        }
    }

    @Test("ChatStreamEvent.toolCallsReady constructs with tool calls")
    func toolCallsReadyCase() {
        let call = ToolCall(id: "call_1", function: FunctionCall(name: "f", arguments: "{}"))
        let event = ChatStreamEvent.toolCallsReady([call])
        if case .toolCallsReady(let calls) = event {
            #expect(calls.count == 1)
            #expect(calls[0].id == "call_1")
        } else {
            Issue.record("Expected .toolCallsReady case")
        }
    }

    @Test("ChatStreamEvent.finished constructs with a ChatMessage")
    func finishedCase() {
        let msg = ChatMessage(role: .assistant, content: "Done")
        let event = ChatStreamEvent.finished(msg)
        if case .finished(let message) = event {
            #expect(message.role == .assistant)
            #expect(message.content == "Done")
        } else {
            Issue.record("Expected .finished case")
        }
    }
}

// MARK: - decodedArguments Tests

struct DecodedArgumentsTests {

    private struct WeatherArgs: Decodable, Equatable {
        let location: String
    }

    private struct NestedArgs: Decodable, Equatable {
        let query: String
        let options: Options

        struct Options: Decodable, Equatable {
            let limit: Int
            let ascending: Bool
        }
    }

    private struct EmptyArgs: Decodable, Equatable {}

    @Test("decodedArguments decodes valid JSON into a Decodable struct")
    func decodesValidJSON() throws {
        let call = ToolCall(
            id: "call_1",
            function: FunctionCall(name: "get_weather", arguments: "{\"location\": \"London\"}")
        )

        let args: WeatherArgs = try call.decodedArguments()
        #expect(args.location == "London")
    }

    @Test("decodedArguments throws on invalid JSON")
    func throwsOnInvalidJSON() {
        let call = ToolCall(
            id: "call_2",
            function: FunctionCall(name: "get_weather", arguments: "not json at all")
        )

        #expect(throws: (any Error).self) {
            let _: WeatherArgs = try call.decodedArguments()
        }
    }

    @Test("decodedArguments throws on empty string arguments")
    func throwsOnEmptyString() {
        let call = ToolCall(
            id: "call_3",
            function: FunctionCall(name: "get_weather", arguments: "")
        )

        #expect(throws: (any Error).self) {
            let _: WeatherArgs = try call.decodedArguments()
        }
    }

    @Test("decodedArguments works with nested objects")
    func decodesNestedObjects() throws {
        let json = """
        {"query": "swift", "options": {"limit": 10, "ascending": true}}
        """
        let call = ToolCall(
            id: "call_4",
            function: FunctionCall(name: "search", arguments: json)
        )

        let args: NestedArgs = try call.decodedArguments()
        #expect(args.query == "swift")
        #expect(args.options.limit == 10)
        #expect(args.options.ascending == true)
    }

    @Test("decodedArguments works with no-argument tools (empty {})")
    func decodesEmptyObject() throws {
        let call = ToolCall(
            id: "call_5",
            function: FunctionCall(name: "get_time", arguments: "{}")
        )

        let args: EmptyArgs = try call.decodedArguments()
        #expect(args == EmptyArgs())
    }

    @Test("decodedArguments accepts a custom JSONDecoder")
    func customDecoder() throws {
        struct SnakeArgs: Decodable, Equatable {
            let cityName: String
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let call = ToolCall(
            id: "call_6",
            function: FunctionCall(name: "f", arguments: "{\"city_name\": \"Paris\"}")
        )

        let args: SnakeArgs = try call.decodedArguments(decoder: decoder)
        #expect(args.cityName == "Paris")
    }

    @Test("decodedArguments type can be inferred or explicit")
    func explicitType() throws {
        let call = ToolCall(
            id: "call_7",
            function: FunctionCall(name: "get_weather", arguments: "{\"location\": \"Tokyo\"}")
        )

        // Explicit type parameter
        let args = try call.decodedArguments(WeatherArgs.self)
        #expect(args.location == "Tokyo")
    }
}
