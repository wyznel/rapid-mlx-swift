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
> Read [TOOL_CALLING_TUTORIAL.md](https://github.com/wyznel/rapid-mlx-swift/blob/main/TOOL_CALLING_TUTORIAL.md) for the full guide including mid-level and low-level approaches.

`chatWithTools` handles the entire tool-calling lifecycle. Define your tools with their execution closures, and the library manages the request/response loop automatically:

```swift
struct WeatherArgs: Codable {
    let location: String
}
struct WeatherResult: Codable {
    let temperature: Int
    let condition: String
}

let weatherTool = Tool<WeatherArgs, WeatherResult>(
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
) { input in
    // Implement tool logic here
    return WeatherResult(temperature: 18, condition: "partly cloudy")
}

let request = ChatCompletionRequest(
    messages: [.user("What is the weather in London?")],
    tools: try [weatherTool].toChatCompletionTools()
)

// Streaming with automatic tool execution
for try await event in try client.chatWithTools(messages: [.user("What is the weather in London?")], tools: [weatherTool]) {
    switch event {
    case .content(let token): print(token, terminator: "")
    case .toolCallsReady: break
    case .finished: break
    }
}

// Or non-streaming:
let response = try await client.chatWithTools(messages: [.user("What is the weather in London?")], tools: [weatherTool])
print(response.firstText ?? "")
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
| `chat(_:model:)` | Send messages with an optional model name |
| `chat(_:)` | Send a fully constructed `ChatCompletionRequest` |
| `chatStream(_:model:)` | Stream raw `ChatCompletionChunk` tokens |
| `chatStream(_:)` | Stream a fully constructed request |
| `chatStreamEvents(_:)` | Stream high-level `ChatStreamEvent` values with automatic delta accumulation |
| `chatWithTools(_:)` | Streaming tool execution loop with automatic multi-round handling |
| `chatWithTools(_:) async throws` | Non-streaming tool execution loop returning the final response |
| `listModels(showOnlyAliases:)` | Query cached models on the server |

### Models

| Type | Description |
|------|-------------|
| `ChatMessage` | A single message with `role`, optional `content`, optional `toolCalls`, and optional `toolCallId` |
| `ChatCompletionRequest` | Request body with `model`, `messages`, optional `tools`, `toolChoice`, and `parallelToolCalls` |
| `ChatCompletionResponse` | Server response containing an array of `choices` |
| `ChatChoice` | A single completion choice with `index`, `message`, and `finishReason` |
| `ChatCompletionChunk` | A single SSE chunk during streaming |
| `ChatStreamEvent` | High-level event: `.content`, `.toolCallsReady`, `.finished` |
| `Tool` | A generic tool definition combining schema and an execution closure |
| `ChatCompletionTool` | The low-level JSON payload representation of a tool |
| `FunctionDefinition` | Describes a callable function with `name`, `description`, and `parameters` |
| `ToolCall` | A tool call returned by the model with `id`, `type`, and `function` |
| `FunctionCall` | The `name` and JSON-encoded `arguments` from a tool call |
| `ToolChoice` | Controls tool selection: `.auto`, `.none`, `.required`, `.function(name:)` |
| `JSONValue` | Type-safe recursive enum for arbitrary JSON (used in tool parameter schemas) |
| `ChunkAccumulator` | Reassembles streaming tool call deltas into complete `ToolCall` objects |

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

// Tool call argument decoding
let args: MyArgs = try toolCall.decodedArguments()

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
    case .streamingError(let message):
        // SSE parsing failure
    case .toolCallError(let message):
        // Tool call argument decoding failure
    }
}
```
## License

See [LICENSE](LICENSE) for details.
