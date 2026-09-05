import Foundation
import Testing
@testable import RapidMLX

struct TransportAndStreamingTests {
    @Test("API URLs accept a server root or an existing v1 path")
    func apiURLNormalization() {
        let root = URL(string: "http://localhost:8000")!
        let v1 = URL(string: "http://localhost:8000/v1")!

        #expect(
            RapidMLXClient.apiURL(baseURL: root, path: "chat/completions").absoluteString
                == "http://localhost:8000/v1/chat/completions"
        )
        #expect(
            RapidMLXClient.apiURL(baseURL: v1, path: "/models/").absoluteString
                == "http://localhost:8000/v1/models"
        )
        #expect(
            RapidMLXClient.serverURL(baseURL: v1, path: "/healthz").absoluteString
                == "http://localhost:8000/healthz"
        )
    }

    @Test("SSE accepts data fields with or without an optional leading space")
    func parsesStandardSSEDataFields() throws {
        let payload = #"{"id":"1","object":"chat.completion.chunk","created":0,"model":"test","choices":[{"index":0,"delta":{"content":"Hi"}}]}"#

        let event = try RapidMLXClient.parseSSELine("data:\(payload)", decoder: JSONDecoder())
        guard case .chunk(let chunk) = event else {
            Issue.record("Expected a decoded SSE chunk")
            return
        }
        #expect(chunk.firstContentToken == "Hi")
    }

    @Test("SSE recognizes the terminal DONE event")
    func parsesSSEDoneEvent() throws {
        let event = try RapidMLXClient.parseSSELine("data: [DONE]", decoder: JSONDecoder())
        guard case .done = event else {
            Issue.record("Expected the SSE terminal event")
            return
        }
    }

    @Test("Chunk accumulation preserves an explicit streamed role")
    func preservesStreamedRole() {
        var accumulator = ChunkAccumulator()
        accumulator.append(
            ChatCompletionChunk(
                id: "1",
                object: "chunk",
                created: 0,
                model: "test",
                choices: [
                    ChatCompletionChunkChoice(
                        index: 0,
                        delta: ChatCompletionChunkDelta(role: .tool, content: "result")
                    )
                ]
            )
        )

        #expect(accumulator.message.role == .tool)
        #expect(accumulator.message.content == "result")
    }

    @Test("Streaming tools reject a non-positive round limit")
    func rejectsInvalidToolRoundLimit() {
        struct Input: Codable {}
        struct Output: Codable {}
        let tool = Tool<Input, Output>(
            name: "noop",
            description: "No operation",
            parameters: [:]
        ) { _ in Output() }
        let client = RapidMLXClient()

        #expect(throws: RapidMLXError.self) {
            let _: AsyncThrowingStream<ChatStreamEvent, Error> = try client.chatWithTools(
                messages: [.user("Hello")],
                tools: [tool],
                maxRounds: 0
            )
        }
    }
}
