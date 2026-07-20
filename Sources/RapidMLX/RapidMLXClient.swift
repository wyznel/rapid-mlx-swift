//
//  RapidMLXClient.swift
//  rapid-mlx-swift
//
//  Created by Ben Herbert on 03/07/2026.
//

import Foundation

public actor RapidMLXClient {
    
    public let baseURL: URL
    public let apiKey: String?
    public let session: URLSession
    public let encoder: JSONEncoder
    public let decoder: JSONDecoder
    
    var process: Process?
    
    public init(
        baseURL: URL = URL(string: "http://localhost:8000")!,
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
        let url = baseURL.appending(path: "/v1/chat/completions")
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
        
        let url = baseURL.appending(path: "/v1/chat/completions")
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
    
    // MARK: - Event-based streaming
    
    /// Streams chat completions as high-level events, automatically accumulating
    /// tool call deltas internally.
    ///
    /// This wraps ``chatStream(_:)-7e1xp`` with a ``ChunkAccumulator`` so consumers
    /// do not need to manually reassemble tool call deltas.
    ///
    /// ```swift
    /// for try await event in client.chatStreamEvents(request) {
    ///     switch event {
    ///     case .content(let token): print(token, terminator: "")
    ///     case .toolCallsReady(let calls): // execute tools
    ///     case .finished(let msg): history.append(msg)
    ///     }
    /// }
    /// ```
    public func chatStreamEvents(
        _ body: ChatCompletionRequest
    ) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        let rawStream = chatStream(body)
        
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var accumulator = ChunkAccumulator()
                    
                    for try await chunk in rawStream {
                        accumulator.append(chunk)
                        
                        if let token = chunk.firstContentToken {
                            continuation.yield(.content(token))
                        }
                        
                        if chunk.isToolCallFinish {
                            let message = accumulator.message
                            if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                                continuation.yield(.toolCallsReady(toolCalls))
                            }
                        }
                    }
                    
                    continuation.yield(.finished(accumulator.message))
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
    
    /// Convenience overload that builds a ``ChatCompletionRequest`` for you.
    public func chatStreamEvents(
        _ messages: [ChatMessage],
        model: String = "default",
        tools: [ChatCompletionTool]? = nil,
        toolChoice: ToolChoice? = nil,
        parallelToolCalls: Bool? = nil
    ) -> AsyncThrowingStream<ChatStreamEvent, Error> {
        let request = ChatCompletionRequest(
            model: model,
            messages: messages,
            tools: tools,
            toolChoice: toolChoice,
            parallelToolCalls: parallelToolCalls
        )
        return chatStreamEvents(request)
    }
    
}


extension RapidMLXClient {
    
    func runCommand(arguments: [String]) throws {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let executable = home
            .appendingPathComponent(".local")
            .appendingPathComponent("bin")
            .appendingPathComponent("rapid-mlx")
        
        let task = Process()
        task.executableURL = executable
        task.arguments = arguments
        let out = Pipe()
        let err = Pipe()
        
        task.standardOutput = out
        task.standardError = err
        
        try task.run()
    }
    
    
}

extension RapidMLXClient {
    
    public func serve(model: String) throws {
        guard process?.isRunning != true else {
            throw RapidMLXError.modelAlreadyServed
        }
        
        let home = FileManager.default.homeDirectoryForCurrentUser
        let executable = home
            .appendingPathComponent(".local")
            .appendingPathComponent("bin")
            .appendingPathComponent("rapid-mlx")
        
        let task = Process()
        task.executableURL = executable
        task.arguments = ["serve", model]
        
        let out = Pipe()
        let err = Pipe()
        task.standardOutput = out
        task.standardError = err
        
        try task.run()
        process = task
    }
    
    public func stopServe() throws {
        guard let process, process.isRunning else { throw RapidMLXError.noModelRunning }
        
        process.terminate()
        process.waitUntilExit()
        self.process = nil
    }
    
}


extension RapidMLXClient {
    
    func fetch<T: Decodable>(_ endpoint: String, as type: T.Type = T.self) async throws -> T {
        let url = baseURL.appendingPathComponent(endpoint.trimmingCharacters(in: CharacterSet(charactersIn: "/")))
        
        let (data, response) = try await session.data(from: url)
        
        do {
            guard let httpResponse = response as? HTTPURLResponse else {
                throw RapidMLXError.invalidResponse
            }
            
            guard 200...299 ~= httpResponse.statusCode else {
                throw RapidMLXError.httpError(statusCode: httpResponse.statusCode, body: "")
            }
        } catch let error as URLError {
            switch error.code {
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet:
                throw RapidMLXError.serverUnavailable
            case .timedOut:
                throw RapidMLXError.timeout
            default:
                throw RapidMLXError.transport(error)
            }
        }
        
        return try decoder.decode(T.self, from: data)
    }
}


extension RapidMLXClient {
    
    public struct HealthResponse: Decodable {
        let status: String
        let ready: Bool
        let model_loaded: Bool
        let model_name: String
    }
    
    public func getHealth() async throws -> HealthResponse {
        let health: HealthResponse = try await fetch("/healthz")
        return health
    }
}

extension RapidMLXClient {
    
    public struct IsModelReady: Decodable {
        let ready: Bool
        let model: String
    }
    
    public func isModelReady() async throws -> IsModelReady {
        let ready: IsModelReady = try await fetch("/health/ready")
        
        return ready
    }
    
    /// Polls the health endpoint until the model is fully loaded and ready to serve requests.
    public func waitForModelReady(pollInterval: TimeInterval = 1.0, maxRetries: Int = 30) async throws {
        for _ in 0..<maxRetries {
            do {
                let status = try await isModelReady()
                if status.ready {
                    return
                }
            } catch {
                // Ignore errors and keep polling (e.g., connection refused while server starts)
            }
            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
        throw RapidMLXError.timeout
    }
    
}
