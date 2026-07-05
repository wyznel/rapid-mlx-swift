//
//  RapidMLXClient.swift
//  rapid-mlx-swift
//
//  Created by Ben Herbert on 03/07/2026.
//

import Foundation

public struct RapidMLXClient: Sendable {
    
    public let baseURL: URL
    public let apiKey: String?
    public let session: URLSession
    public let encoder: JSONEncoder
    public let decoder: JSONDecoder
    
    
    public init(
        baseURL: URL = URL(string: "http://localhost:8000/v1")!,
        apiKey: String? = "not-needed",
        session: URLSession = .shared,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ){
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.session = session
        self.encoder = encoder
        self.decoder = decoder
    }

//  MARK: - General Chat (No streaming)
    public func chat(
        _ messages: [ChatMessage],
        model: String = "default"
    ) async throws -> ChatCompletionResponse {
        
        let requestBody = ChatCompletionRequest(
            model: model,
            messages: messages
        )
        
        return try await chat(requestBody)
    }
    
    public func chat(_ body: ChatCompletionRequest) async throws -> ChatCompletionResponse {
        let url = baseURL.appending(path: "chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RapidMLXError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let responseBody = String(data: data, encoding: .utf8)
            throw RapidMLXError.httpError(
                statusCode: httpResponse.statusCode,
                body: responseBody
            )
        }
        
        let decoded = try decoder.decode(ChatCompletionResponse.self, from: data)
        
        guard !decoded.choices.isEmpty else {
            throw RapidMLXError.emptyChoices
        }
        
        
        return decoded
    }
    
    // MARK: - Streaming chat
    
    public func chatStream(
        _ messages: [ChatMessage],
        model: String = "default"
    ) -> AsyncThrowingStream<ChatCompletionChunk, Error> {
        let requestBody = ChatCompletionRequest(
            model: model,
            messages: messages,
            stream: true
        )
        return chatStream(requestBody)
    }
    
    public func chatStream(
        _ body: ChatCompletionRequest
    ) -> AsyncThrowingStream<ChatCompletionChunk, Error> {
        let streamBody = ChatCompletionRequest(
            model: body.model,
            messages: body.messages,
            stream: true,
            tools: body.tools,
            toolChoice: body.toolChoice,
            parallelToolCalls: body.parallelToolCalls
        )
        
        let url = baseURL.appending(path: "chat/completions")
        let currentEncoder = encoder
        let currentDecoder = decoder
        let currentApiKey = apiKey
        let currentSession = session
        
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    
                    if let apiKey = currentApiKey, !apiKey.isEmpty {
                        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    }
                    
                    request.httpBody = try currentEncoder.encode(streamBody)
                    
                    let (bytes, response) = try await currentSession.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw RapidMLXError.invalidResponse
                    }
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        var errorData = Data()
                        for try await byte in bytes {
                            errorData.append(byte)
                        }
                        let errorBody = String(data: errorData, encoding: .utf8)
                        throw RapidMLXError.httpError(
                            statusCode: httpResponse.statusCode,
                            body: errorBody
                        )
                    }
                    
                    for try await line in bytes.lines {
                        if let event = try Self.parseSSELine(line, decoder: currentDecoder) {
                            switch event {
                            case .chunk(let chunk):
                                continuation.yield(chunk)
                            case .done:
                                break
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
    
    // MARK: - SSE parsing
    
    private enum SSEEvent {
        case chunk(ChatCompletionChunk)
        case done
    }
    
    private static func parseSSELine(
        _ line: String,
        decoder: JSONDecoder
    ) throws -> SSEEvent? {
        guard !line.isEmpty, !line.hasPrefix(":") else {
            return nil
        }
        
        guard line.hasPrefix("data: ") else {
            return nil
        }
        
        let payload = String(line.dropFirst(6))
        
        if payload == "[DONE]" {
            return .done
        }
        
        guard let data = payload.data(using: .utf8) else {
            throw RapidMLXError.streamingError("Invalid UTF-8 in SSE payload")
        }
        
        let chunk = try decoder.decode(ChatCompletionChunk.self, from: data)
        return .chunk(chunk)
    }
    
    // MARK: - List currently cached models
    
    public func listModels(showOnlyAliases: Bool = false) async throws -> ListModelResponse {
        let url = baseURL.appending(path: "models")
        var request = URLRequest(url: url)
        
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RapidMLXError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else{
            let responseBody = String(data: data, encoding: .utf8)
            throw RapidMLXError.httpError(statusCode: httpResponse.statusCode, body: responseBody)
        }
        
        let decoded = try decoder.decode(ListModelResponse.self, from: data)
        
        
        if showOnlyAliases {
            return ListModelResponse(
                object: decoded.object,
                models: decoded.models.filter { !$0.id.contains("/") }
            )
        }
        
        return decoded
    }
    
}
