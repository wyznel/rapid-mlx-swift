# AGENTS.md

## Project purpose

This repository contains a Swift Package that provides a native Swift client for talking to a local Rapid-MLX server over its OpenAI-compatible HTTP API.[cite:4][cite:2]
Rapid-MLX exposes a local endpoint at `http://localhost:8000/v1` and supports the standard chat completions surface used by OpenAI-compatible clients.[cite:4][cite:2]

## What this package is

The package is intentionally thin.
It is not a Swift binding to MLX internals, Python code, or model execution.
It is a transport and model layer around Rapid-MLX's local HTTP server, starting with `POST /v1/chat/completions`.[cite:4][cite:2]

## Core assumptions

- Target platform: modern macOS on Apple Silicon.
- The package talks to a running Rapid-MLX instance, not to models directly.[cite:2][cite:4]
- Default base URL is `http://localhost:8000/v1`.[cite:4]
- Default starter model is `default`, matching Rapid-MLX examples.[cite:4][cite:24]
- Local API keys are typically set to `not-needed` in OpenAI-compatible clients when using Rapid-MLX locally.[cite:24][cite:4]

## Recommended architecture

Keep the package split into small, obvious layers:

- `Models.swift`: core request/response structs.
- `ChatMessage+Extensions.swift`: convenience constructors such as `.user(...)`.
- `ChatCompletionResponse+Convenience.swift`: helpers such as `firstText`.
- `RapidMLXClient.swift`: HTTP transport and request execution.
- `Errors.swift`: focused package errors.

Prefer extending the existing client and models over adding parallel abstractions unless a new endpoint genuinely requires them.

## Current scope

The supported flows are:

1. Build a `ChatCompletionRequest`.
2. Send it to `/chat/completions` under the configured base URL.[cite:4][cite:2]
3. Decode the response.
4. Read assistant output from `choices[0].message.content` or a convenience property built on that shape.[cite:4]

Streaming chat is also supported via `chatStream`, which returns an `AsyncThrowingStream<ChatCompletionChunk, Error>` over SSE chunks from the same endpoint with `stream: true`.

Keep the package focused on correctness and API clarity before adding richer features like tool calling, embeddings, or multimodal support, even though Rapid-MLX supports broader OpenAI-compatible capabilities.[cite:2][cite:24]

## How to run locally

Install and start Rapid-MLX first, then run package tests against it.
Rapid-MLX documents local setup via Homebrew or pip, then serving a model such as `qwen3.5-4b` or `qwen3.5-9b` to expose an OpenAI-compatible server on localhost.[cite:2][cite:4][cite:24]

Typical local flow:

```bash
brew install raullenchai/rapid-mlx/rapid-mlx
rapid-mlx serve qwen3.5-4b
# wait for: Ready: http://localhost:8000/v1
swift test
```

Rapid-MLX also documents direct manual verification with:

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"default","messages":[{"role":"user","content":"Say hello"}]}'
```
[cite:4]

## Testing expectations

Maintain two test layers:

- Unit tests for model construction and decoding.
- Integration tests that hit a real local Rapid-MLX server.[cite:4][cite:36]

Integration tests should assume the developer has already started the local server.
If a test depends on localhost, keep the failure message explicit so the next agent immediately knows to check whether Rapid-MLX is running.

## Coding guidelines for agents

- Prefer small, additive changes.
- Do not redesign the public API unless there is a concrete need.
- Preserve a clean Swift-native surface, even when the underlying wire format is OpenAI-compatible JSON.
- Keep `Codable` models minimal; only model fields that the package actively uses.
- Use stable, older Foundation APIs when they reduce avoidable availability friction.
- Avoid introducing heavyweight dependencies unless the package gets a clear benefit.

## API design guidelines

When adding new endpoints, follow the same pattern:

- Add minimal request/response models.
- Add one client method per endpoint.
- Add unit coverage for model encoding/decoding.
- Add one integration test against a real local server when practical.

For likely next endpoints, prefer this order:

1. Streaming chat.
2. Tool-calling support.
3. Embeddings.
4. Responses API.

Rapid-MLX documents compatibility with `/v1/chat/completions` and `/v1/responses`, and it positions itself as a drop-in OpenAI-compatible backend for many existing clients and frameworks.[cite:2][cite:4]

## Versioning and release expectations

This package should be distributed as a normal source Swift package from Git.
Swift Package Manager publishes packages through Git repositories with semantic version tags such as `0.1.0`.[cite:140][cite:156]

Before release, keep these items up to date:

- `Package.swift`
- `README.md`
- `LICENSE`
- source and test targets
- semantic version tag history

## What not to do

- Do not attempt to embed Rapid-MLX's Python runtime or MLX inference engine in this package.
- Do not treat this package as a general OpenAI SDK clone.
- Do not silently expand scope into UI, model management, or process orchestration unless the repository explicitly decides to do so.
- Do not assume cloud-hosted inference; the primary path is local Rapid-MLX on the same Mac.[cite:2][cite:4]

## Fast orientation checklist

A new coding agent should do this first:

1. Read `Package.swift`.
2. Read `README.md`.
3. Inspect `Sources/RapidMLX/` and `Tests/RapidMLXTests/`.
4. Confirm the package still targets the intended macOS baseline.
5. Confirm Rapid-MLX is running locally before debugging integration failures.[cite:4]
6. Run `swift test` before making changes.

## One-sentence mental model

This project is a Swift-native, source-distributed client library for Rapid-MLX's local OpenAI-compatible API, starting with chat completions on `http://localhost:8000/v1`.[cite:2][cite:4]
