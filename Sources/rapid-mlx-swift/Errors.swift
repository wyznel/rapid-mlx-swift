//
//  Errors.swift
//  rapid-mlx-swift
//
//  Created by Ben Herbert on 03/07/2026.
//

import Foundation

public enum RapidMLXError: Error, Sendable, Equatable {
    case invalidBaseURL
    case invalidResponse
    case httpError(statusCode: Int, body: String?)
    case emptyChoices
}
