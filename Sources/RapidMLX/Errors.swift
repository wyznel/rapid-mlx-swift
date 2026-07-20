//
//  Errors.swift
//  rapid-mlx-swift
//
//  Created by Ben Herbert on 03/07/2026.
//

import Foundation

public enum RapidMLXError: Error, Sendable {
    case invalidBaseURL
    case invalidResponse
    case httpError(statusCode: Int, body: String?)
    case emptyChoices
    case streamingError(String)
    case toolCallError(String)
    case modelAlreadyServed
    case noModelRunning
    case serverUnavailable
    case timeout
    case transport(Error)
    case invalidCommand(String)
}
