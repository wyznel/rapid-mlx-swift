# RapidMLX Swift Package Roadmap

This roadmap lays out a practical release path for a Swift-native client library that talks to a local Rapid-MLX server over its OpenAI-compatible API.[cite:2][cite:4]
Rapid-MLX already exposes chat, responses, embeddings, tool calling, streaming-oriented usage, and multimodal capabilities through a local server at `http://localhost:8000/v1`, so the package roadmap should grow in thin, well-tested layers rather than trying to abstract everything at once.[cite:2][cite:4]

## Release strategy

The package should be released as a source Swift package from Git and versioned with semantic tags.[cite:163][cite:164]
Because versions below `1.0.0` are generally treated as unstable, the `0.x` line is the right place to refine API shape before freezing a stable public interface.[cite:164]

## v0.1.0

### Goal

Ship the smallest public package that is genuinely useful: a Swift-native chat client for a local Rapid-MLX server.[cite:2][cite:4]

### Scope

- Swift Package with a clean public library product.
- Core `Codable` request and response models for chat completions.
- `RapidMLXClient` with a default base URL of `http://localhost:8000/v1`.[cite:4]
- Default chat path for `POST /v1/chat/completions`.[cite:4]
- Minimal error surface.
- Unit tests for models.
- Live integration test against a local Rapid-MLX server.[cite:4]
- README with installation and a one-request quick start.

### Exit criteria

- `swift test` passes locally.
- A user can start Rapid-MLX, call `chat`, and read the assistant reply from the decoded response.[cite:4]
- The package can be tagged and consumed from another Swift project as a dependency.[cite:163][cite:164]

## v0.2.0

### Goal

Improve ergonomics without materially widening scope.

### Scope

- Better request customization, such as explicit model override and transport configuration.
- Cleaner error reporting for non-2xx API responses.
- Test fixtures for decoding known-good responses.
- Better convenience APIs such as `firstText`, `firstMessage`, and light response helpers.
- More robust README examples for local setup and troubleshooting.[cite:4][cite:27]

### Exit criteria

- Public API remains small and readable.
- Common failure cases produce clear Swift errors.
- The package feels comfortable to use in a command-line tool or macOS app.

## v0.3.0

### Goal

Add streaming chat support.

### Why here

Rapid-MLX positions low TTFT and streaming as an important part of the developer experience, so a Swift package should expose that early once the non-streaming base is stable.[cite:2][cite:31]

### Scope

- Support streamed chat completions.
- Expose streamed chunks in a Swift-native form, likely `AsyncSequence` or callback-based iteration.
- Add tests that verify chunk decoding and final assembly.
- Document how streaming differs from the existing one-shot `chat` flow.

### Exit criteria

- A caller can consume tokens incrementally.
- The streaming API does not make the simple one-shot API harder to understand.

## v0.4.0

### Goal

Add tool-calling support.

### Why here

Rapid-MLX emphasizes tool calling heavily and advertises strong support for it, including many parser formats and recovery behavior, so this is one of the highest-value next capabilities after plain chat.[cite:2][cite:4]

### Scope

- Model `tool_calls` in chat responses.
- Add request-side tool definitions.
- Add a lightweight Swift representation for tool schemas and calls.
- Add tests for basic tool-call decoding and round-tripping.
- Avoid building a full agent framework; stay at the protocol/client layer.[cite:4]

### Exit criteria

- A caller can send tool definitions and inspect returned tool calls.
- The package remains a client library, not an orchestration framework.

## v0.5.0

### Goal

Add embeddings.

### Why here

Rapid-MLX documents text embeddings alongside chat and multimodal capabilities, and embeddings are a natural second endpoint for downstream app developers building local search or RAG-style features.[cite:4]

### Scope

- Add request/response models for embeddings.
- Add `embeddings(...)` client methods.
- Add decode tests and one integration test.
- Document how embeddings fit local app use cases.

### Exit criteria

- A caller can generate embeddings from Swift against the local Rapid-MLX server.
- API design matches the simplicity of the chat surface.

## v0.6.0

### Goal

Add the Responses API.

### Why here

Rapid-MLX explicitly states compatibility with both Chat and Responses APIs, so supporting both lets the package serve users who want a more modern OpenAI-style surface without abandoning the chat API.[cite:2][cite:4]

### Scope

- Add models for `/v1/responses`.
- Add client methods for creating responses.
- Keep shared transport and error handling common between endpoints.
- Document when to choose Chat Completions versus Responses.

### Exit criteria

- Both Chat Completions and Responses are supported cleanly.
- Shared abstractions reduce duplication without hiding endpoint-specific behavior.

## v0.7.0

### Goal

Add multimodal foundations.

### Why here

Rapid-MLX documents vision, audio, video understanding, and related multimodal functionality through the same OpenAI-compatible API family, but these add payload complexity and should come after the text-first API is settled.[cite:4]

### Scope

- Support structured content parts rather than string-only message content.
- Add image URL or binary-reference-friendly request models where appropriate.
- Ensure the chat API can evolve without breaking the v0 text-only path too aggressively.
- Add documentation for optional extras and server-side prerequisites such as vision installs.[cite:4]

### Exit criteria

- Multimodal requests are possible without making text-only use awkward.
- The type system remains understandable.

## v0.8.0

### Goal

Stabilize the public API for a 1.0 release.

### Scope

- Audit naming consistency.
- Remove obviously temporary conveniences.
- Mark any deprecated pre-1.0 surfaces.
- Expand test coverage and examples.
- Add a `CHANGELOG.md` and release notes discipline.[cite:164]
- Validate consumer experience in a separate demo app or sample package.

### Exit criteria

- Public API feels coherent.
- The maintainers are confident the package surface will not need major redesign immediately after `1.0.0`.

## v1.0.0

### Goal

Declare a stable core API.

### Scope

- Stable chat client.
- Stable error model.
- Stable streaming surface, if included by this point.
- Stable endpoint families that have proven useful in real projects.
- Release-quality docs and examples.

### Exit criteria

- SemVer expectations are now strict for consumers.[cite:164]
- Future breaking API changes require a major version bump.[cite:164]

## Post-1.0 candidates

These should be treated as optional or demand-driven rather than mandatory:

- Public tunnel and hosted-endpoint helpers for Rapid-MLX share flows, if the project chooses to expose them.[cite:4]
- Cloud-routing-aware configuration surfaces, if Rapid-MLX routing behavior becomes important to client authors.[cite:4]
- Swift macros or higher-level DSLs for tools.
- Stronger typed wrappers for structured outputs.
- Sample macOS app or menu bar demo.
- Performance diagnostics and observability helpers.

## Suggested milestones table

| Version | Focus | Why it matters |
|---|---|---|
| `0.1.0` | Basic chat package | First usable public release.[cite:4] |
| `0.2.0` | Ergonomics and polish | Makes the package nicer without expanding too fast. |
| `0.3.0` | Streaming | Matches Rapid-MLX's low-latency usage story.[cite:2][cite:31] |
| `0.4.0` | Tool calling | High-value capability Rapid-MLX strongly supports.[cite:2][cite:4] |
| `0.5.0` | Embeddings | Opens up local retrieval and indexing use cases.[cite:4] |
| `0.6.0` | Responses API | Covers a second major OpenAI-compatible surface.[cite:2] |
| `0.7.0` | Multimodal foundations | Enables vision and richer inputs later.[cite:4] |
| `0.8.0` | API stabilization | Prepares for `1.0.0`. |
| `1.0.0` | Stable package | Consumer-facing API contract is now firm.[cite:164] |

## Guiding principle

Every version should keep the package thin, well-tested, and obviously mapped to Rapid-MLX's local OpenAI-compatible server rather than drifting into a full framework or agent runtime.[cite:2][cite:4]
