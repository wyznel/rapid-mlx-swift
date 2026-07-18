# RapidMLX Swift Package Roadmap

This roadmap lays out a practical release path for a Swift-native client library that talks to a local Rapid-MLX server over its OpenAI-compatible API.
Rapid-MLX already exposes chat, responses, embeddings, tool calling, streaming-oriented usage, and multimodal capabilities through a local server at `http://localhost:8000/v1`, so the package roadmap should grow in thin, well-tested layers rather than trying to abstract everything at once.

## Release strategy

The package should be released as a source Swift package from Git and versioned with semantic tags.
Because versions below `1.0.0` are generally treated as unstable, the `0.x` line is the right place to refine API shape before freezing a stable public interface.

---

## Released versions

### v0.1.0

#### Goal

Ship the smallest public package that is genuinely useful: a Swift-native chat client for a local Rapid-MLX server.

#### Delivered

- Swift Package with a clean public library product.
- Core `Codable` request and response models for chat completions.
- `RapidMLXClient` with a default base URL of `http://localhost:8000/v1`.
- Default chat path for `POST /v1/chat/completions`.
- Minimal error surface.
- Unit tests for models.
- Live integration test against a local Rapid-MLX server.
- README with installation and a one-request quick start.

### v0.1.5

#### Goal

Add model discovery capabilities.

#### Delivered

- `listModels()` client method for querying cached models on the server.
- Tests for model listing.

### v0.1.5.1

#### Goal

Bug fix for model listing.

#### Delivered

- Fixed `listModels()` which was returning both the alias and HF repo as separate models.
- Added `showOnlyAliases` flag to control listing behavior.

### v0.2.0

#### Goal

Add streaming chat support alongside ergonomic improvements.

#### Delivered

- Streaming chat completions via `chatStream` methods.
- `AsyncSequence`-based streaming using `AsyncThrowingStream<ChatCompletionChunk, Error>`.
- SSE (Server-Sent Events) parsing for streamed responses.
- Convenience extensions: `firstText`, `firstMessage` on `ChatCompletionResponse`.
- Streaming extensions: `firstContentToken`, `isFinished` on `ChatCompletionChunk`.
- Static factory methods on `ChatMessage` (`.system()`, `.user()`, `.assistant()`).
- Better error reporting for non-2xx API responses.
- LICENSE file (MIT).
- ROADMAP and AGENTS documentation.

### v0.3.0

#### Goal

Finish adding tool calling support, making it much easier while still allowing access to mid and lower level access.

#### Delivered

- `Tool`, `FunctionDefinition` request-side types for defining callable functions.
- `ToolCall`, `FunctionCall` response-side types for model-emitted tool calls.
- `ToolCallChunkDelta`, `FunctionCallDelta` for streaming tool call deltas.
- `ToolChoice` enum (`.auto`, `.none`, `.required`, `.function(name:)`) with polymorphic Codable.
- `JSONValue` recursive enum for type-safe arbitrary JSON in tool parameter schemas.
- `ChatMessage.content` changed from `String` to `String?` (breaking) to support tool call responses.
- `ChatMessage.toolCalls` and `ChatMessage.toolCallId` fields.
- `ChatMessage.toolResult(callId:content:)` factory method.
- `tools`, `toolChoice`, `parallelToolCalls` fields on `ChatCompletionRequest`.
- `toolCalls` field on `ChatCompletionChunkDelta` for streaming.    
- Convenience extensions: `firstToolCalls`, `hasToolCalls`, `firstToolCallDeltas`, `isToolCallFinish`.
- Fixed `chatStream` to preserve tool fields when rebuilding the request with `stream: true`.
- 22 unit tests for tool calling types, encoding, and decoding.
- 3 integration tests: non-streaming tool call, full round-trip, streaming tool call.

###### Simplifying tool calling.

- `ChatStreamEvent` enum (`.content`, `.toolCallsReady`, `.finished`) for consuming streams without manual delta accumulation.
- `chatStreamEvents` methods on `RapidMLXClient` that wrap raw chunk streams with internal `ChunkAccumulator`.
- `chatWithTools` streaming method that handles the full tool execution lifecycle (stream, accumulate, execute, follow-up) with `maxRounds` safety limit.
- `chatWithTools` non-streaming method for simpler use cases.
- Generic `Tool<Input, Output>` type storing both schema and execution logic.
- `ToolCall.decodedArguments()` generic helper for typed argument parsing.
- `toolCallError` case added to `RapidMLXError`.
- All new APIs are additive; existing low-level `chatStream` API unchanged.

---

## Upcoming versions

### v0.4.0

#### Goal

Add embeddings.

#### Why here

Rapid-MLX documents text embeddings alongside chat and multimodal capabilities, and embeddings are a natural second endpoint for downstream app developers building local search or RAG-style features.

#### Scope

- Add request/response models for embeddings.
- Add `embeddings(...)` client methods.
- Add decode tests and one integration test.
- Document how embeddings fit local app use cases.

#### Exit criteria

- A caller can generate embeddings from Swift against the local Rapid-MLX server.
- API design matches the simplicity of the chat surface.

### v0.5.0

#### Goal

Add the Responses API.

#### Why here

Rapid-MLX explicitly states compatibility with both Chat and Responses APIs, so supporting both lets the package serve users who want a more modern OpenAI-style surface without abandoning the chat API.

#### Scope

- Add models for `/v1/responses`.
- Add client methods for creating responses.
- Keep shared transport and error handling common between endpoints.
- Document when to choose Chat Completions versus Responses.

#### Exit criteria

- Both Chat Completions and Responses are supported cleanly.
- Shared abstractions reduce duplication without hiding endpoint-specific behavior.

### v0.6.0

#### Goal

Add multimodal foundations.

#### Why here

Rapid-MLX documents vision, audio, video understanding, and related multimodal functionality through the same OpenAI-compatible API family, but these add payload complexity and should come after the text-first API is settled.

#### Scope

- Support structured content parts rather than string-only message content.
- Add image URL or binary-reference-friendly request models where appropriate.
- Ensure the chat API can evolve without breaking the text-only path too aggressively.
- Add documentation for optional extras and server-side prerequisites such as vision installs.

#### Exit criteria

- Multimodal requests are possible without making text-only use awkward.
- The type system remains understandable.

### v0.7.0

#### Goal

Stabilize the public API for a 1.0 release.

#### Scope

- Audit naming consistency.
- Remove obviously temporary conveniences.
- Mark any deprecated pre-1.0 surfaces.
- Expand test coverage and examples.
- Add a `CHANGELOG.md` and release notes discipline.
- Validate consumer experience in a separate demo app or sample package.

#### Exit criteria

- Public API feels coherent.
- The maintainers are confident the package surface will not need major redesign immediately after `1.0.0`.

### v1.0.0

#### Goal

Declare a stable core API.

#### Scope

- Stable chat client.
- Stable error model.
- Stable streaming surface.
- Stable endpoint families that have proven useful in real projects.
- Release-quality docs and examples.


## Milestones table

| Version | Focus | Status |
|---|---|---|
| `0.1.0` | Basic chat package | Released |
| `0.1.5` | Model listing | Released |
| `0.1.5.1` | Model listing bug fix | Released |
| `0.2.0` | Streaming, ergonomics, convenience APIs | Released |
| `0.3.0` | Tool calling | Released |
| `0.3.1` | Tool calling ergonomics | Released |
| `0.4.0` | Embeddings | Planned |
| `0.5.0` | Responses API | Planned |
| `0.6.0` | Multimodal foundations | Planned |
| `0.7.0` | API stabilization | Planned |
| `1.0.0` | Stable package | Planned |

