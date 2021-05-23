//  Errors.swift
//
//  Copyright 2015 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

public enum AwfulCoreError: Error {
    case invalidUsernameOrPassword
    case parseError(description: String)
    case forbidden(description: String)
    case databaseUnavailable
    case archivesRequired
}

extension AwfulCoreError: CustomNSError {
    public static var errorDomain: String { "AwfulCoreErrorDomain" }

    public var errorCode: Int {
        switch self {
        case .invalidUsernameOrPassword: return 1
        case .parseError: return 3
        case .forbidden: return 6
        case .databaseUnavailable: return 7
        case .archivesRequired: return 8
        }
    }

    public var errorUserInfo: [String: Any] {
        switch self {
        case .forbidden(description: let description) where !description.isEmpty,
             .parseError(description: let description) where !description.isEmpty:
            return [NSLocalizedDescriptionKey: description]
        case .invalidUsernameOrPassword, .parseError, .forbidden, .databaseUnavailable, .archivesRequired:
            return [:]
        }
    }
}
