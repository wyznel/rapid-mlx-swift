# Tool Calling Tutorial

> [!NOTE]
> This tutorial uses `catfact.ninja` as a free, no-auth endpoint to demonstrate tool calling.

## How it Works

The LLM does not execute code. It tells you which function to call, you execute it, and you send the result back so the LLM can generate a final response.

```mermaid
sequenceDiagram
    participant App as Your Swift Code
    participant LLM as Rapid-MLX
    participant API as catfact.ninja

    App->>LLM: "Tell me a cat fact" + [get_cat_fact]
    LLM->>App: call get_cat_fact()
    App->>API: GET /fact
    API->>App: {"fact": "...", "length": 30}
    App->>LLM: Tool Result: {"fact": "..."}
    LLM->>App: "Here's a fun cat fact..."
```

## Basic Example (Non-Streaming)

Here is a complete, single-turn tool calling flow:

```swift
import Foundation
import RapidMLX

func catFactDemo() async throws {
    let client = RapidMLXClient()

    let catFactTool = Tool(function: FunctionDefinition(
        name: "get_cat_fact",
        description: "Retrieves a random cat fact",
        parameters: .object(["type": "object", "properties": .object([:]), "required": .array([])])
    ))

    // 1. Initial request with tools
    let request = ChatCompletionRequest(
        messages: [.user("Tell me a cat fact")],
        tools: [catFactTool],
        toolChoice: .auto
    )
    let response = try await client.chat(request)

    // 2. Check for tool calls
    guard response.hasToolCalls, let toolCall = response.firstToolCalls?.first else {
        print(response.firstText ?? "No response")
        return
    }

    // 3. Execute function
    let (data, _) = try await URLSession.shared.data(from: URL(string: "https://catfact.ninja/fact")!)
    let resultJSON = String(data: data, encoding: .utf8) ?? "{}"

    // 4. Send result back
    let followUp = ChatCompletionRequest(
        messages: [
            .user("Tell me a cat fact"),
            response.firstMessage!,
            .toolResult(callId: toolCall.id, content: resultJSON)
        ],
        tools: [catFactTool]
    )
    let finalResponse = try await client.chat(followUp)
    
    print(finalResponse.firstText ?? "")
}
```

## Handling Multiple Tool Calls in a Loop

If a task might require multiple tool calls in sequence, loop the interaction:

```swift
var messages: [ChatMessage] = [.user("Tell me 3 cat facts")]

for _ in 0..<10 { // Safety limit
    let res = try await client.chat(ChatCompletionRequest(messages: messages, tools: [catFactTool]))

    guard res.hasToolCalls, let calls = res.firstToolCalls else {
        print(res.firstText ?? "")
        break
    }

    messages.append(res.firstMessage!)

    for call in calls {
        let (data, _) = try await URLSession.shared.data(from: URL(string: "https://catfact.ninja/fact")!)
        messages.append(.toolResult(callId: call.id, content: String(data: data, encoding: .utf8) ?? "{}"))
    }
}
```

## Streaming Tool Calls

When streaming, tool calls arrive as incremental deltas. Use `ChunkAccumulator` to automatically assemble these chunks into a complete `ChatMessage`.

```swift
func streamingCatFactDemo() async throws {
    let client = RapidMLXClient()
    let catFactTool = Tool(function: FunctionDefinition(
        name: "get_cat_fact",
        description: "Retrieves a cat fact",
        parameters: .object(["type": "object", "properties": .object([:]), "required": .array([])])
    ))

    var accumulator = ChunkAccumulator()
    var gotToolCalls = false

    // 1. Stream the request and accumulate
    let request = ChatCompletionRequest(messages: [.user("Tell me a cat fact")], tools: [catFactTool])
    for try await chunk in client.chatStream(request) {
        accumulator.append(chunk)
        
        if let token = chunk.firstContentToken {
            print(token, terminator: "")
        }
        if chunk.isToolCallFinish {
            gotToolCalls = true
        }
    }

    guard gotToolCalls else {
        print()
        return
    }

    // 2. Execute calls and follow up
    let assistantMsg = accumulator.message
    var messages: [ChatMessage] = [.user("Tell me a cat fact"), assistantMsg]

    for call in assistantMsg.toolCalls ?? [] {
        let (data, _) = try await URLSession.shared.data(from: URL(string: "https://catfact.ninja/fact")!)
        messages.append(.toolResult(callId: call.id, content: String(data: data, encoding: .utf8) ?? "{}"))
    }

    for try await chunk in client.chatStream(ChatCompletionRequest(messages: messages, tools: [catFactTool])) {
        if let token = chunk.firstContentToken {
            print(token, terminator: "")
        }
    }
    print()
}
```
