//
//  Model.swift
//  RapidMLX
//
//  Created by Ben Herbert on 04/07/2026.
//

public struct Model: Codable, Sendable, Equatable {
    public let id: String
    public let object: String
    public let created: Int
    public let ownedBy: String
    public let recommendedSampling: String?
    public let isHybrid: Bool
    public let isMoe: Bool
    public let toolCallParser: String
    public let reasoningParser: String
    public let modality: String
    public let contextWindow: Int
    public let capabilities: [String]
    public let audioLanes: [String]?

    enum CodingKeys: String, CodingKey {
        case id, object, created, capabilities, modality
        case ownedBy = "owned_by"
        case recommendedSampling = "recommended_sampling"
        case isHybrid = "is_hybrid"
        case isMoe = "is_moe"
        case toolCallParser = "tool_call_parser"
        case reasoningParser = "reasoning_parser"
        case contextWindow = "context_window"
        case audioLanes = "audio_lanes"
    }
}

public struct ModelResponse: Codable, Sendable, Equatable {
    public let object: String
    public let models: [Model]
    
    enum CodingKeys: String, CodingKey {
        case object
        case models = "data"
    }
}
