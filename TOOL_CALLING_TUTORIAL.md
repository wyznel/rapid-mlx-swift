# Tool Calling Tutorial

> [!NOTE]
> This tutorial uses `catfact.ninja` as a free, no-auth endpoint to demonstrate tool calling.

## Quick Start: `chatWithTools`

The simplest way to use tool calling. Define your tool, provide a handler closure, and the library manages the entire request/response loop, including multi-round tool calls.

### Streaming

```swift
import Foundation
import RapidMLX

struct CatFactResult: Codable {
    let fact: String
}
struct EmptyArgs: Codable {}

func catFactDemo() async throws {
    let client = RapidMLXClient()

    let catFactTool = Tool<EmptyArgs, CatFactResult>(
        name: "get_cat_fact",
        description: "Retrieves a random cat fact",
        parameters: [
            "type": "object",
            "properties": [:],
            "required": []
        ]
    ) { _ in
        let (data, _) = try await URLSession.shared.data(
            from: URL(string: "https://catfact.ninja/fact")!
        )
        return try JSONDecoder().decode(CatFactResult.self, from: data)
    }

    for try await event in try client.chatWithTools(
        messages: [.user("Tell me 3 cat facts")],
        tools: [catFactTool]
    ) {
        switch event {
        case .content(let token):
            print(token, terminator: "")
        case .toolCallsReady:
            break  // Optional: show "calling tool..." in your UI
        case .finished:
            print()
        }
    }
}
```

### Non-Streaming

For cases where you do not need to stream tokens:

```swift
let response = try await client.chatWithTools(
    messages: [.user("Tell me 3 cat facts")],
    tools: [catFactTool]
)
print(response.firstText ?? "")
```

## Typed Argument Decoding

When inspecting a raw `ToolCall`, you can use `decodedArguments()` to decode the JSON arguments into a Swift struct instead of parsing the raw string:

```swift
struct WeatherArgs: Decodable {
    let location: String
}

// Inside your tool execution logic:
let args: WeatherArgs = try call.decodedArguments()
print(args.location)  // "London"
```

## Multiple Tools

You can provide multiple tools in the `tools` array. The model automatically determines which tool to call based on the user's prompt.

```swift
let response = try await client.chatWithTools(
    messages: [.user("What is the weather in London? Also, tell me a cat fact.")],
    tools: [weatherTool, catFactTool]
)
```

## Error Handling

If a tool's handler closure throws an error, it is caught and sent back to the model as a tool result error message. The model can then attempt to recover, retry with different arguments, or explain the failure to the user.

## Configuration

You can control the maximum number of back-and-forth tool calling rounds using the `maxRounds` parameter. This prevents infinite loops if the model gets stuck calling tools repeatedly.

```swift
for try await event in try client.chatWithTools(
    messages: [.user("Tell me 100 cat facts")],
    tools: [catFactTool],
    maxRounds: 5 // Stop after 5 round trips
) {
    // ...
}
```
