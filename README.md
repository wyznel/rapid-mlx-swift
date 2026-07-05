> [!NOTE]
> This project is not directly affiliated with [RapidMLX](https://github.com/raullenchai/Rapid-MLX), it is developed and maintained independently.
# RapidMLX Swift

A lightweight Swift client for interacting with the [RapidMLX](https://github.com/raullenchai/Rapid-MLX) api.

## Requirements

- Swift 6.3+
- macOS 15+ / iOS 16+

## Installation

Add the package to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/wyznel/rapid-mlx-swift.git", from: "0.2.7")
]
```

## Usage

### Quick start

```swift
import RapidMLX

let client = RapidMLXClient()

let response = try await client.chat([
    .system("You are a helpful assistant."),
    .user("What is MLX?")
])

print(response.firstText ?? "No response")
```

### Custom server URL

```swift
let client = RapidMLXClient(
    baseURL: URL(string: "http://192.168.1.42:8000/v1")!,
    apiKey: "my-api-key"
)
```

### Using a specific model

```swift
let response = try await client.chat(
    [.user("Hello")],
    model: "mlx-community/Llama-3-8B-Instruct-4bit"
)
```

### Building a request manually

```swift
let request = ChatCompletionRequest(
    model: "default",
    messages: [
        .user("Reply with the word: ok")
    ]
)

let response = try await client.chat(request)
```

### Streaming chat

```swift
for try await chunk in client.chatStream([.user("Tell me a story")]) {
    if let token = chunk.firstContentToken {
        print(token, terminator: "")
    }
}
print() // newline after stream ends
```

### Tool calling
> [!NOTE]
> Read (TOOL_CALLING_TUTORIAL.md)[https://github.com/wyznel/rapid-mlx-swift/blob/main/TOOL_CALLING_TUTORIAL.md] for more.

```swift
// 1. Define a tool
let weatherTool = Tool(function: FunctionDefinition(
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

// 2. Send a request with tools
let request = ChatCompletionRequest(
    messages: [.user("What is the weather in London?")],
    tools: [weatherTool],
    toolChoice: .auto
)
let response = try await client.chat(request)

// 3. Inspect tool calls
if response.hasToolCalls, let toolCalls = response.firstToolCalls {
    for call in toolCalls {
        print(call.function.name)       // "get_weather"
        print(call.function.arguments)  // "{\"location\": \"London\"}"

        // 4. Execute the function yourself, then send the result back
        let result = ChatMessage.toolResult(
            callId: call.id,
            content: "{\"temperature\": 18, \"condition\": \"partly cloudy\"}"
        )

        let followUp = ChatCompletionRequest(
            messages: [
                .user("What is the weather in London?"),
                response.firstMessage!,
                result
            ],
            tools: [weatherTool]
        )
        let finalResponse = try await client.chat(followUp)
        print(finalResponse.firstText ?? "")
    }
}
```

## API Reference

### `RapidMLXClient`

| Property | Type | Default |
|----------|------|---------|
| `baseURL` | `URL` | `http://localhost:8000/v1` |
| `apiKey` | `String?` | `"not-needed"` |
| `session` | `URLSession` | `.shared` |
| `encoder` | `JSONEncoder` | `JSONEncoder()` |
| `decoder` | `JSONDecoder` | `JSONDecoder()` |

**Methods**

| Signature | Description |
|-----------|-------------|
| `chat(_:model:) async throws -> ChatCompletionResponse` | Send messages with an optional model name |
| `chat(_:) async throws -> ChatCompletionResponse` | Send a fully constructed `ChatCompletionRequest` |
| `chatStream(_:model:) -> AsyncThrowingStream<ChatCompletionChunk, Error>` | Stream tokens with an optional model name |
| `chatStream(_:) -> AsyncThrowingStream<ChatCompletionChunk, Error>` | Stream a fully constructed request |

### Models

| Type | Description |
|------|-------------|
| `ChatMessage` | A single message with `role`, optional `content`, optional `toolCalls`, and optional `toolCallId` |
| `ChatCompletionRequest` | Request body with `model`, `messages`, optional `tools`, `toolChoice`, and `parallelToolCalls` |
| `ChatCompletionResponse` | Server response containing an array of `choices` |
| `ChatChoice` | A single completion choice with `index`, `message`, and `finishReason` |
| `ChatCompletionChunk` | A single SSE chunk during streaming |
| `ChatCompletionChunkChoice` | A streaming choice with `index`, `delta`, and `finishReason` |
| `ChatCompletionChunkDelta` | Incremental token data with optional `role`, `content`, and `toolCalls` |
| `Tool` | A tool definition wrapping a `FunctionDefinition` |
| `FunctionDefinition` | Describes a callable function with `name`, `description`, and `parameters` |
| `ToolCall` | A tool call returned by the model with `id`, `type`, and `function` |
| `FunctionCall` | The `name` and JSON-encoded `arguments` from a tool call |
| `ToolCallChunkDelta` | A partial tool call delta during streaming |
| `ToolChoice` | Controls tool selection: `.auto`, `.none`, `.required`, `.function(name:)` |
| `JSONValue` | Type-safe recursive enum for arbitrary JSON (used in tool parameter schemas) |

### Convenience helpers

```swift
// Message construction
ChatMessage.system("You are helpful.")
ChatMessage.user("Hello")
ChatMessage.assistant("Hi there")
ChatMessage.toolResult(callId: "call_abc", content: "{...}")

// Response access
response.firstMessage     // ChatMessage?
response.firstText        // String?
response.firstToolCalls   // [ToolCall]?
response.hasToolCalls     // Bool

// Streaming chunk access
chunk.firstContentToken     // String?
chunk.isFinished            // Bool
chunk.firstToolCallDeltas   // [ToolCallChunkDelta]?
chunk.isToolCallFinish      // Bool
```

### Error handling

```swift
do {
    let response = try await client.chat([.user("Hello")])
} catch let error as RapidMLXError {
    switch error {
    case .invalidBaseURL:
        // Malformed base URL
    case .invalidResponse:
        // Response was not a valid HTTP response
    case .httpError(let statusCode, let body):
        // Server returned a non-2xx status
    case .emptyChoices:
        // Response contained no choices
    }
}
```

## Project structure

```
Sources/RapidMLX/
  RapidMLXClient.swift                              -- HTTP client
  Models.swift                                      -- Request/response types
  ToolModels.swift                                  -- Tool calling types
  JSONValue.swift                                   -- Arbitrary JSON enum
  Errors.swift                                      -- RapidMLXError enum
  Extensions/
    ChatMessage+Extensions.swift                    -- Role enum & factory methods
    ChatCompletionResponse+Extensions.swift         -- firstMessage / firstText / firstToolCalls
    ChatCompletionChunk+Extensions.swift            -- firstContentToken / isFinished / isToolCallFinish
Tests/RapidMLXTests/
  RapidMLXTests.swift                               -- Core unit & integration tests
  ToolCallingTests.swift                            -- Tool calling unit tests
  ToolCallIntegrationTests.swift                    -- Tool calling integration tests
```

## License

See [LICENSE](LICENSE) for details.
