//
//  Tool.swift
//  rapid-mlx-swift
//
//

import Foundation

/// Protocol defining the requirements for a tool that can be used with RapidMLX
public protocol ToolProtocol: Sendable {
    /// The JSON Schema describing the tool's interface
    var schema: any (Codable & Sendable) { get }
}

public typealias Value = JSONValue

/// A type representing a tool that can be used with RapidMLX.
///
/// Tools allow models to perform complex tasks
/// or interact with the outside world by calling functions, APIs,
/// or other services.
public struct Tool<Input: Codable, Output: Codable>: ToolProtocol {
    public var schema: any (Codable & Sendable) { schemaValue }
    private(set) var schemaValue: Value

    private let implementation: @Sendable (Input) async throws -> Output

    public init(
        schema: [String: Value],
        implementation: @Sendable @escaping (Input) async throws -> Output
    ) {
        self.schemaValue = Value.object([
            "type": .string("function"),
            "function": .object(schema),
        ])
        self.implementation = implementation
    }

    public init(
        name: String,
        description: String,
        parameters: [String: Value],
        required: [String] = [],
        implementation: @Sendable @escaping (Input) async throws -> Output
    ) {
        var propertiesObject: [String: Value] = parameters
        var requiredParams = required

        if case .string("object") = parameters["type"],
            case .object(let props) = parameters["properties"]
        {
            propertiesObject = props

            if required.isEmpty,
                case .array(let reqArray) = parameters["required"]
            {
                requiredParams = reqArray.compactMap { value in
                    if case .string(let str) = value {
                        return str
                    }
                    return nil
                }
            }
        }

        self.init(
            schema: [
                "name": .string(name),
                "description": .string(description),
                "parameters": .object([
                    "type": .string("object"),
                    "properties": .object(propertiesObject),
                    "required": .array(requiredParams.map { .string($0) }),
                ]),
            ],
            implementation: implementation
        )
    }

    public func callAsFunction(_ input: Input) async throws -> Output {
        try await implementation(input)
    }
}

// MARK: - Auto-Execution Type Erasure

protocol ExecutableTool {
    var name: String? { get }
    func execute(arguments: String) async throws -> String
}

extension Tool: ExecutableTool {
    var name: String? {
        if case .object(let dict) = schemaValue,
           case .object(let funcDict) = dict["function"],
           case .string(let name) = funcDict["name"] {
            return name
        }
        return nil
    }

    func execute(arguments: String) async throws -> String {
        guard let data = arguments.data(using: .utf8) else {
            throw RapidMLXError.toolCallError("Invalid arguments")
        }
        let input = try JSONDecoder().decode(Input.self, from: data)
        let result = try await self.callAsFunction(input)
        let outputData = try JSONEncoder().encode(result)
        return String(data: outputData, encoding: .utf8) ?? "{}"
    }
}

// MARK: - Request Conversion

extension Array where Element == any ToolProtocol {
    public func toChatCompletionTools() throws -> [ChatCompletionTool] {
        return try self.map { toolProtocol in
            // ToolProtocol's schema natively uses `any (Codable & Sendable)`, but AnyCodable encoding can be tricky.
            // Since we know schemaValue is JSONValue (or encodable as such), we can just encode it.
            let encoded = try JSONEncoder().encode(toolProtocol.schema)
            return try JSONDecoder().decode(ChatCompletionTool.self, from: encoded)
        }
    }
}
