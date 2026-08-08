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
    /// The forums handed back the poll form again instead of accepting the poll.
    case pollSubmissionRejected(message: String?)
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
        case .pollSubmissionRejected: return 9
        }
    }

    public var errorUserInfo: [String: Any] {
        switch self {
        case .forbidden(description: let description) where !description.isEmpty,
             .parseError(description: let description) where !description.isEmpty,
             .pollSubmissionRejected(message: .some(let description)) where !description.isEmpty:
            return [NSLocalizedDescriptionKey: description]
        case .pollSubmissionRejected:
            return [NSLocalizedDescriptionKey: String(
                localized: "The forums didn't accept the poll.",
                bundle: .module
            )]
        case .invalidUsernameOrPassword, .parseError, .forbidden, .databaseUnavailable, .archivesRequired:
            return [:]
        }
    }
}
