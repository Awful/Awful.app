//  IndexScrapeResult.swift
//
//  Copyright 2020 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

/**
 `index.php?format=json`

 Assumes a date decoding strategy of `.secondsSince1970`.
 */
public struct IndexScrapeResult: Decodable {
    public let currentUser: ScrapedProfile
    public let forums: [ScrapedForum]
    public let stats: Stats?

    private enum CodingKeys: String, CodingKey {
        case currentUser = "user"
        case forums
        case stats
    }

    public struct ScrapedForum: Decodable {
        public let description: String?
        public let hasThreads: Bool
        @EmptyStringNil public private(set) var icon: URL?
        @IntOrString public private(set) var id: String
        @DefaultEmpty public private(set) var moderators: [Moderator]
        public let shortTitle: String?
        @DefaultEmpty public private(set) var subforums: [ScrapedForum]
        public let title: String

        private enum CodingKeys: String, CodingKey {
            case description
            case hasThreads = "has_threads"
            case icon
            case id
            case moderators
            case shortTitle = "title_short"
            case subforums = "sub_forums"
            case title
        }

        public struct Moderator: Decodable {
            @IntOrString public private(set) var userID: String
            public let username: String

            private enum CodingKeys: String, CodingKey {
                case userID = "userid"
                case username
            }
        }
    }

    public struct ScrapedProfile: Decodable {
        public let aim: String?
        public let biography: String?
        @IntToBool public private(set) var canReceivePrivateMessages: Bool?
        /// Probably a fragment of HTML
        public let customTitle: String?
        public let gender: String?
        public let homepage: String?
        public let icq: String?
        public let interests: String?
        public let lastPostDate: Date?
        public let location: String?
        public let occupation: String?
        public let picture: String?
        public let postCount: Int?
        public let postsPerDay: Double?
        public let regdate: Date?
        public let role: String?
        @IntOrString public private(set) var userID: String
        public let username: String
        public let yahoo: String?

        private enum CodingKeys: String, CodingKey {
            case aim = "aim"
            case biography = "biography"
            case canReceivePrivateMessages = "receivepm"
            case customTitle = "usertitle"
            case gender = "gender"
            case homepage = "homepage"
            case icq = "icq"
            case interests = "interests"
            case lastPostDate = "lastpost"
            case location = "location"
            case occupation = "occupation"
            case picture = "picture"
            case postCount = "posts"
            case postsPerDay = "postsperday"
            case regdate = "joindate"
            case role = "role"
            case userID = "userid"
            case username = "username"
            case yahoo = "yahoo"
        }
    }

    public struct Stats: Decodable {
        public let archivedPosts: Int?
        public let archivedThreads: Int?
        public let bannedUsersToday: Int?
        public let bannedUsersTotal: Int?
        public let postCount: Int?
        public let registeredUsersOnline: Int?
        public let threadCount: Int?
        public let userCount: Int?
        public let usersOnlineTotal: Int?

        private enum CodingKeys: String, CodingKey {
            case archivedPosts = "archived_posts"
            case archivedThreads = "archived_threads"
            case bannedUsersToday = "banned_users"
            case bannedUsersTotal = "banned_users_total"
            case postCount = "unique_posts"
            case registeredUsersOnline = "online_registered"
            case threadCount = "unique_threads"
            case userCount = "usercount"
            case usersOnlineTotal = "online_total"
        }
    }
}

extension IndexScrapeResult {
    public var allForums: AnySequence<(node: ScrapedForum, depth: Int)> {
        AnySequence(ConcatSequence(
            forums.lazy.map { forum in
                DepthFirstSequence(root: forum, children: \.subforums)
            }
        ))
    }
}
