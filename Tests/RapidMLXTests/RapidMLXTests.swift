import Testing
import Foundation
@testable import RapidMLX

@Test func example() async throws {
    // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    // Swift Testing Documentation
    // https://developer.apple.com/documentation/testing
}

struct ModelsTests {
//    @Test func modelConstruction() {
//        let request = ChatCompletionRequest(messages: [.user("Say hello")])
//        let response = ChatCompletionResponse(choices: [
//            ChatChoice(message: .assistant("Hello!"))
//        ])
//        
//        #expect(request.model == "default")
//        #expect(request.messages.first?.content == "Say hello")
//        #expect(response.firstText == "Hello!")
//    }
    
    
//    @Test func localChatRequest() async throws {
//        let client = RapidMLXClient()
//        let response = try await client.chat([
//            .user("Say hello in five words or fewer.")
//        ])
//
//        #expect(response.firstText != nil)
//        #expect(!(response.firstText ?? "").isEmpty)
//    }
    
//    @Test("Local Rapid-MLX chat request returns text")
//    func localChatRequestReturnsText() async throws {
//        let client = RapidMLXClient()
//
//        let response = try await client.chat([
//            .user("Say hello in five words or fewer.")
//        ])
//
//        let text = try #require(response.firstText)
//        #expect(!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
//    }
    
    @Test("Explicit chat request works")
    func explicitRequestWorks() async throws {
        let client = RapidMLXClient()
        let request = ChatCompletionRequest(
            messages: [.user("Reply with the word: ok")]
        )

        let response = try await client.chat(request)
        let text = try #require(response.firstText)
        #expect(!text.isEmpty)
    }
    
    @Test("List models works")
    func listModelsWorks() async throws {
        let client = RapidMLXClient()
        let modelResponse: ListModelResponse = try await client.listModels(showOnlyAliases: true)
        
        let Models: [Model] = modelResponse.models
        
        #expect(Models.count > 0)
        
    }
}

// MARK: - Streaming tests

struct StreamingModelTests {
    @Test("Streaming chunk decodes correctly")
    func chunkDecoding() throws {
        let json = """
        {"id":"chatcmpl-abc","object":"chat.completion.chunk","created":1234567890,\
        "model":"test","choices":[{"index":0,"delta":{"content":"Hello"},"finish_reason":null}]}
        """
        let chunk = try JSONDecoder().decode(ChatCompletionChunk.self, from: Data(json.utf8))
        #expect(chunk.firstContentToken == "Hello")
        #expect(!chunk.isFinished)
    }

    @Test("Final streaming chunk has finish_reason")
    func finalChunkDecoding() throws {
        let json = """
        {"id":"chatcmpl-abc","object":"chat.completion.chunk","created":1234567890,\
        "model":"test","choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}
        """
        let chunk = try JSONDecoder().decode(ChatCompletionChunk.self, from: Data(json.utf8))
        #expect(chunk.firstContentToken == nil)
        #expect(chunk.isFinished)
    }

    @Test("Role-only chunk decodes without content")
    func roleOnlyChunkDecoding() throws {
        let json = """
        {"id":"chatcmpl-abc","object":"chat.completion.chunk","created":1234567890,\
        "model":"test","choices":[{"index":0,"delta":{"role":"assistant"}}]}
        """
        let chunk = try JSONDecoder().decode(ChatCompletionChunk.self, from: Data(json.utf8))
        #expect(chunk.firstContentToken == nil)
        #expect(!chunk.isFinished)
    }

    @Test("ChatCompletionRequest encodes stream field")
    func requestEncodesStream() throws {
        let request = ChatCompletionRequest(messages: [.user("Hi")], stream: true)
        let data = try JSONEncoder().encode(request)
        let json = String(data: data, encoding: .utf8)!
        #expect(json.contains("\"stream\":true"))
    }

    @Test("ChatCompletionRequest omits stream when nil")
    func requestOmitsStreamWhenNil() throws {
        let request = ChatCompletionRequest(messages: [.user("Hi")])
        let data = try JSONEncoder().encode(request)
        let json = String(data: data, encoding: .utf8)!
        #expect(!json.contains("stream"))
    }
}

struct StreamingIntegrationTests {
    @Test("Streaming chat returns tokens from live server")
    func streamingIntegration() async throws {
        let client = RapidMLXClient()
        var tokens: [String] = []

        for try await chunk in client.chatStream([.user("Say hello in 3 words")]) {
            if let token = chunk.firstContentToken {
                tokens.append(token)
            }
        }

        let fullText = tokens.joined()
        #expect(!fullText.isEmpty)
    }
}
