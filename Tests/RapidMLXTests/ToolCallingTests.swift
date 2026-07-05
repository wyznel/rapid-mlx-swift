import Testing
import Foundation
@testable import RapidMLX

// MARK: - JSONValue Tests

struct JSONValueTests {
    @Test("JSONValue round-trips a realistic JSON Schema tree")
    func jsonValueRoundTrip() throws {
        let schema: JSONValue = .object([
            "type": "object",
            "properties": .object([
                "location": .object([
                    "type": "string",
                    "description": "The city name"
                ]),
                "unit": .object([
                    "type": "string",
                    "enum": .array(["celsius", "fahrenheit"])
                ])
            ]),
            "required": .array(["location"])
        ])

        let data = try JSONEncoder().encode(schema)
        let decoded = try JSONDecoder().decode(JSONValue.self, from: data)
        #expect(decoded == schema)
    }

    @Test("JSONValue decodes all primitive types")
    func primitiveDecoding() throws {
        let json = """
        {"s":"hello","n":42.5,"b":true,"a":[1,2],"null":null}
        """
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        guard case .object(let dict) = value else {
            Issue.record("Expected object")
            return
        }
        #expect(dict["s"] == .string("hello"))
        #expect(dict["n"] == .number(42.5))
        #expect(dict["b"] == .bool(true))
        #expect(dict["a"] == .array([.number(1), .number(2)]))
        #expect(dict["null"] == .null)
    }

    @Test("JSONValue literal conformances work")
    func literalConformances() {
        let str: JSONValue = "hello"
        let num: JSONValue = 42
        let flt: JSONValue = 3.14
        let boolVal: JSONValue = true
        let nilVal: JSONValue = nil

        #expect(str == .string("hello"))
        #expect(num == .number(42))
        #expect(flt == .number(3.14))
        #expect(boolVal == .bool(true))
        #expect(nilVal == .null)
    }
}

// MARK: - ToolChoice Tests

struct ToolChoiceTests {
    @Test("ToolChoice.auto encodes as string")
    func encodesAuto() throws {
        let data = try JSONEncoder().encode(ToolChoice.auto)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == "\"auto\"")
    }

    @Test("ToolChoice.none encodes as string")
    func encodesNone() throws {
        let data = try JSONEncoder().encode(ToolChoice.none)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == "\"none\"")
    }

    @Test("ToolChoice.required encodes as string")
    func encodesRequired() throws {
        let data = try JSONEncoder().encode(ToolChoice.required)
        let json = String(data: data, encoding: .utf8)!
        #expect(json == "\"required\"")
    }

    @Test("ToolChoice.function encodes as object")
    func encodesFunction() throws {
        let data = try JSONEncoder().encode(ToolChoice.function(name: "get_weather"))
        let obj = try JSONDecoder().decode([String: JSONValue].self, from: data)
        #expect(obj["type"] == .string("function"))
        guard case .object(let funcDict) = obj["function"] else {
            Issue.record("Expected function object")
            return
        }
        #expect(funcDict["name"] == .string("get_weather"))
    }

    @Test("All ToolChoice variants survive encode-decode round trip")
    func roundTrip() throws {
        let cases: [ToolChoice] = [.auto, .none, .required, .function(name: "foo")]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for original in cases {
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(ToolChoice.self, from: data)
            #expect(decoded == original)
        }
    }
}

// MARK: - Tool Call Response Decoding

struct ToolCallResponseTests {
    @Test("Decodes non-streaming tool call response from live server capture")
    func toolCallResponseDecoding() throws {
        let json = """
        {
          "id": "chatcmpl-ed9988e3",
          "choices": [{
            "index": 0,
            "message": {
              "role": "assistant",
              "content": "",
              "tool_calls": [{
                "id": "call_6654edbe",
                "type": "function",
                "function": {
                  "name": "get_weather",
                  "arguments": "{\\"location\\": \\"London\\"}"
                }
              }]
            },
            "finish_reason": "tool_calls"
          }]
        }
        """

        let response = try JSONDecoder().decode(ChatCompletionResponse.self, from: Data(json.utf8))
        #expect(response.hasToolCalls)

        let toolCalls = try #require(response.firstToolCalls)
        #expect(toolCalls.count == 1)
        #expect(toolCalls[0].id == "call_6654edbe")
        #expect(toolCalls[0].type == "function")
        #expect(toolCalls[0].function.name == "get_weather")
        #expect(toolCalls[0].function.arguments == "{\"location\": \"London\"}")
    }

    @Test("Decodes message with null content (tool call without text)")
    func nullContentDecoding() throws {
        let json = """
        {"role":"assistant","content":null,"tool_calls":[{"id":"call_1","type":"function","function":{"name":"f","arguments":"{}"}}]}
        """
        let message = try JSONDecoder().decode(ChatMessage.self, from: Data(json.utf8))
        #expect(message.content == nil)
        #expect(message.toolCalls?.count == 1)
    }

    @Test("Decodes message with empty string content")
    func emptyContentDecoding() throws {
        let json = """
        {"role":"assistant","content":""}
        """
        let message = try JSONDecoder().decode(ChatMessage.self, from: Data(json.utf8))
        #expect(message.content == "")
        #expect(message.toolCalls == nil)
    }

    @Test("hasToolCalls is false when no tool calls present")
    func noToolCallsResponse() throws {
        let json = """
        {"choices":[{"index":0,"message":{"role":"assistant","content":"Hello!"},"finish_reason":"stop"}]}
        """
        let response = try JSONDecoder().decode(ChatCompletionResponse.self, from: Data(json.utf8))
        #expect(!response.hasToolCalls)
        #expect(response.firstText == "Hello!")
    }
}

// MARK: - Tool Call Streaming Chunk Decoding

struct ToolCallStreamChunkTests {
    @Test("Decodes streaming tool call delta chunk")
    func toolCallStreamChunkDecoding() throws {
        let json = """
        {"id":"chatcmpl-abc","object":"chat.completion.chunk","created":1234567890,\
        "model":"test","choices":[{"index":0,"delta":{\
        "tool_calls":[{"index":0,"id":"call_fd1d8a44","type":"function",\
        "function":{"name":"get_weather","arguments":"{\\"location\\": \\"London\\"}"}}],\
        "content":""}}]}
        """
        let chunk = try JSONDecoder().decode(ChatCompletionChunk.self, from: Data(json.utf8))
        let deltas = try #require(chunk.firstToolCallDeltas)
        #expect(deltas.count == 1)
        #expect(deltas[0].index == 0)
        #expect(deltas[0].id == "call_fd1d8a44")
        #expect(deltas[0].function?.name == "get_weather")
    }

    @Test("Decodes streaming finish chunk with tool_calls reason")
    func toolCallFinishChunk() throws {
        let json = """
        {"id":"chatcmpl-abc","object":"chat.completion.chunk","created":1234567890,\
        "model":"test","choices":[{"index":0,"delta":{},"finish_reason":"tool_calls"}]}
        """
        let chunk = try JSONDecoder().decode(ChatCompletionChunk.self, from: Data(json.utf8))
        #expect(chunk.isToolCallFinish)
        #expect(chunk.isFinished)
    }

    @Test("Regular text chunk is not a tool call finish")
    func regularChunkNotToolCallFinish() throws {
        let json = """
        {"id":"chatcmpl-abc","object":"chat.completion.chunk","created":1234567890,\
        "model":"test","choices":[{"index":0,"delta":{"content":"Hello"},"finish_reason":null}]}
        """
        let chunk = try JSONDecoder().decode(ChatCompletionChunk.self, from: Data(json.utf8))
        #expect(!chunk.isToolCallFinish)
        #expect(chunk.firstToolCallDeltas == nil)
    }
}

// MARK: - Tool Result Message Encoding

struct ToolResultMessageTests {
    @Test("Tool result message encodes correctly")
    func toolResultMessageEncoding() throws {
        let msg = ChatMessage.toolResult(
            callId: "call_6654edbe",
            content: "{\"temperature\": 18, \"condition\": \"partly cloudy\"}"
        )

        let data = try JSONEncoder().encode(msg)
        let json = try JSONDecoder().decode([String: JSONValue].self, from: data)

        #expect(json["role"] == .string("tool"))
        #expect(json["tool_call_id"] == .string("call_6654edbe"))
        #expect(json["content"] == .string("{\"temperature\": 18, \"condition\": \"partly cloudy\"}"))
    }
}

// MARK: - Request With Tools Encoding

struct RequestWithToolsTests {
    @Test("ChatCompletionRequest with tools encodes correctly")
    func requestWithToolsEncoding() throws {
        let weatherTool = Tool(function: FunctionDefinition(
            name: "get_weather",
            description: "Get the weather for a location",
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

        let request = ChatCompletionRequest(
            messages: [.user("What is the weather in London?")],
            tools: [weatherTool],
            toolChoice: .auto
        )

        let data = try JSONEncoder().encode(request)
        let json = try JSONDecoder().decode([String: JSONValue].self, from: data)

        // Verify tools array exists
        guard case .array(let tools) = json["tools"] else {
            Issue.record("Expected tools array")
            return
        }
        #expect(tools.count == 1)

        // Verify tool_choice
        #expect(json["tool_choice"] == .string("auto"))
    }

    @Test("Request without tools omits tools and tool_choice keys")
    func requestWithoutToolsOmitsKeys() throws {
        let request = ChatCompletionRequest(messages: [.user("Hi")])
        let data = try JSONEncoder().encode(request)
        let json = String(data: data, encoding: .utf8)!
        #expect(!json.contains("tools"))
        #expect(!json.contains("tool_choice"))
        #expect(!json.contains("parallel_tool_calls"))
    }

    @Test("Request with parallel_tool_calls encodes the key")
    func parallelToolCallsEncoding() throws {
        let request = ChatCompletionRequest(
            messages: [.user("Hi")],
            tools: [Tool(function: FunctionDefinition(name: "f"))],
            parallelToolCalls: false
        )
        let data = try JSONEncoder().encode(request)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"parallel_tool_calls\":false"))
    }
}

// MARK: - Assistant Message With Tool Calls Decoding

struct AssistantToolCallMessageTests {
    @Test("Assistant message with tool_calls and empty content decodes")
    func assistantMessageWithToolCalls() throws {
        let json = """
        {
          "role": "assistant",
          "content": "",
          "tool_calls": [{
            "id": "call_abc123",
            "type": "function",
            "function": {
              "name": "search",
              "arguments": "{\\"query\\": \\"Swift\\"}"
            }
          }]
        }
        """
        let msg = try JSONDecoder().decode(ChatMessage.self, from: Data(json.utf8))
        #expect(msg.role == .assistant)
        #expect(msg.content == "")
        #expect(msg.toolCalls?.count == 1)
        #expect(msg.toolCalls?[0].function.name == "search")
        #expect(msg.toolCallId == nil)
    }
}

// MARK: - Chunk Accumulator Tests

struct ChunkAccumulatorTests {
    @Test("Accumulates text chunks correctly")
    func accumulatesTextChunks() {
        var accumulator = ChunkAccumulator()
        
        let chunk1 = ChatCompletionChunk(id: "1", object: "chunk", created: 0, model: "test", choices: [
            ChatCompletionChunkChoice(index: 0, delta: ChatCompletionChunkDelta(content: "Hello "))
        ])
        let chunk2 = ChatCompletionChunk(id: "2", object: "chunk", created: 0, model: "test", choices: [
            ChatCompletionChunkChoice(index: 0, delta: ChatCompletionChunkDelta(content: "world!"))
        ])
        
        accumulator.append(chunk1)
        accumulator.append(chunk2)
        
        let msg = accumulator.message
        #expect(msg.role == .assistant)
        #expect(msg.content == "Hello world!")
        #expect(msg.toolCalls == nil)
    }
    
    @Test("Accumulates single tool call correctly")
    func accumulatesSingleToolCall() throws {
        var accumulator = ChunkAccumulator()
        
        // Chunk 1: Tool call ID and name
        accumulator.append(ChatCompletionChunk(id: "1", object: "chunk", created: 0, model: "test", choices: [
            ChatCompletionChunkChoice(index: 0, delta: ChatCompletionChunkDelta(
                toolCalls: [
                    ToolCallChunkDelta(index: 0, id: "call_abc", type: "function", function: FunctionCallDelta(name: "get_weather", arguments: ""))
                ]
            ))
        ]))
        
        // Chunk 2: First part of arguments
        accumulator.append(ChatCompletionChunk(id: "2", object: "chunk", created: 0, model: "test", choices: [
            ChatCompletionChunkChoice(index: 0, delta: ChatCompletionChunkDelta(
                toolCalls: [
                    ToolCallChunkDelta(index: 0, function: FunctionCallDelta(arguments: "{\"loc"))
                ]
            ))
        ]))
        
        // Chunk 3: Second part of arguments
        accumulator.append(ChatCompletionChunk(id: "3", object: "chunk", created: 0, model: "test", choices: [
            ChatCompletionChunkChoice(index: 0, delta: ChatCompletionChunkDelta(
                toolCalls: [
                    ToolCallChunkDelta(index: 0, function: FunctionCallDelta(arguments: "ation\": \"London\"}"))
                ]
            ))
        ]))
        
        let msg = accumulator.message
        #expect(msg.role == .assistant)
        #expect(msg.content == nil)
        
        let tools = try #require(msg.toolCalls)
        #expect(tools.count == 1)
        #expect(tools[0].id == "call_abc")
        #expect(tools[0].function.name == "get_weather")
        #expect(tools[0].function.arguments == "{\"location\": \"London\"}")
    }
    
    @Test("Accumulates parallel tool calls correctly")
    func accumulatesParallelToolCalls() throws {
        var accumulator = ChunkAccumulator()
        
        // Chunk 1: Two tool calls start
        accumulator.append(ChatCompletionChunk(id: "1", object: "chunk", created: 0, model: "test", choices: [
            ChatCompletionChunkChoice(index: 0, delta: ChatCompletionChunkDelta(
                toolCalls: [
                    ToolCallChunkDelta(index: 0, id: "call_0", type: "function", function: FunctionCallDelta(name: "get_weather", arguments: "")),
                    ToolCallChunkDelta(index: 1, id: "call_1", type: "function", function: FunctionCallDelta(name: "get_time", arguments: ""))
                ]
            ))
        ]))
        
        // Chunk 2: Arguments for both
        accumulator.append(ChatCompletionChunk(id: "2", object: "chunk", created: 0, model: "test", choices: [
            ChatCompletionChunkChoice(index: 0, delta: ChatCompletionChunkDelta(
                toolCalls: [
                    ToolCallChunkDelta(index: 0, function: FunctionCallDelta(arguments: "{\"location\":\"Paris\"}")),
                    ToolCallChunkDelta(index: 1, function: FunctionCallDelta(arguments: "{\"location\":\"Tokyo\"}"))
                ]
            ))
        ]))
        
        let msg = accumulator.message
        let tools = try #require(msg.toolCalls)
        
        #expect(tools.count == 2)
        #expect(tools[0].id == "call_0")
        #expect(tools[0].function.name == "get_weather")
        #expect(tools[0].function.arguments == "{\"location\":\"Paris\"}")
        
        #expect(tools[1].id == "call_1")
        #expect(tools[1].function.name == "get_time")
        #expect(tools[1].function.arguments == "{\"location\":\"Tokyo\"}")
    }
}

