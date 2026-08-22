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
    /// We tried to vote on a poll that came without a ballot: either it's closed, or we already voted.
    case pollVotingUnavailable
    /// The selection wouldn't be accepted, so we didn't bother sending it.
    case pollVoteInvalid(message: String)
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
        case .pollVotingUnavailable: return 10
        case .pollVoteInvalid: return 11
        }
    }

    public var errorUserInfo: [String: Any] {
        switch self {
        case .forbidden(description: let description) where !description.isEmpty,
             .parseError(description: let description) where !description.isEmpty,
             .pollSubmissionRejected(message: .some(let description)) where !description.isEmpty,
             .pollVoteInvalid(message: let description) where !description.isEmpty:
            return [NSLocalizedDescriptionKey: description]
        case .pollSubmissionRejected:
            return [NSLocalizedDescriptionKey: String(
                localized: "The forums didn't accept the poll.",
                bundle: .module
            )]
        case .pollVotingUnavailable:
            return [NSLocalizedDescriptionKey: String(
                localized: "This poll isn't taking votes.",
                bundle: .module
            )]
        case .invalidUsernameOrPassword, .parseError, .forbidden, .databaseUnavailable, .archivesRequired,
             .pollVoteInvalid:
            return [:]
        }
    }
}
