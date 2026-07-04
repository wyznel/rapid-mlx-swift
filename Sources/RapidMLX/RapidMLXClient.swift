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
    
    // MARK: - Streaming generations
    
    
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
