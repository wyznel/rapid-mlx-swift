# RapidMLX Swift

A lightweight Swift client for the [MLX](https://github.com/ml-explore/mlx) local inference server, providing an OpenAI-compatible chat completions API.

## Requirements

- Swift 6.3+
- macOS 15+ / iOS 16+

## Installation

Add the package to your `Package.swift` dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/wyznel/rapid-mlx-swift.git", from: "0.2.0")
]
```

Then add `RapidMLX` to your target's dependencies:

```swift
.target(
    name: "YourApp",
    dependencies: ["RapidMLX"]
)
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
| `ChatMessage` | A single message with a `role` and `content` |
| `ChatCompletionRequest` | Request body containing `model` and `messages` |
| `ChatCompletionResponse` | Server response containing an array of `choices` |
| `ChatChoice` | A single completion choice with `index`, `message`, and `finishReason` |
| `ChatCompletionChunk` | A single SSE chunk during streaming |
| `ChatCompletionChunkChoice` | A streaming choice with `index`, `delta`, and `finishReason` |
| `ChatCompletionChunkDelta` | Incremental token data with optional `role` and `content` |

### Convenience helpers

```swift
// Message construction
ChatMessage.system("You are helpful.")
ChatMessage.user("Hello")
ChatMessage.assistant("Hi there")

// Response access
response.firstMessage  // ChatMessage?
response.firstText     // String?

// Streaming chunk access
chunk.firstContentToken  // String?
chunk.isFinished         // Bool
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
Sources/rapid-mlx-swift/
  RapidMLXClient.swift                              -- HTTP client
  Models.swift                                      -- Request/response types
  Errors.swift                                      -- RapidMLXError enum
  Extenstions/
    ChatMessage+Extensions.swift                    -- Role enum & factory methods
    ChatCompletionResponse+Extensions.swift         -- firstMessage / firstText
    ChatCompletionChunk+Extensions.swift            -- firstContentToken / isFinished
Tests/rapid-mlx-swiftTests/
  RapidMLXTests.swift                               -- Unit & integration tests
```

## License

See [LICENSE](LICENSE) for details.
