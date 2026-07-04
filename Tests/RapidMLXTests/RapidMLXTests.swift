import Testing
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
