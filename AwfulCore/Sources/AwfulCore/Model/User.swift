//  User.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData
import HTMLReader

@objc(User)
public class User: AwfulManagedObject, Managed {
    public static var entityName: String { "User" }
    
    @NSManaged public var administrator: Bool
    @NSManaged public var authorClasses: String?
    @NSManaged public var canReceivePrivateMessages: Bool
    @NSManaged public var customTitleHTML: String?
    @NSManaged var lastModifiedDate: Date
    @NSManaged public var moderator: Bool
    @NSManaged public var regdate: Date?
    @NSManaged public var regdateRaw: String?
    @NSManaged public var userID: String
    @NSManaged public var username: String?

    @NSManaged var announcements: Set<Announcement>
    @NSManaged var posts: Set<Post>
    @NSManaged public var profile: Profile?
    @NSManaged var receivedPrivateMessages: Set<PrivateMessage> /* via to */
    @NSManaged var sentPrivateMessages: Set<PrivateMessage> /* via from */
    @NSManaged var threadFilters: Set<ThreadFilter>
    @NSManaged var threads: Set<AwfulThread>

    public override var objectKey: UserKey {
        .init(userID: userID, username: username)
    }

    public override func awakeFromInsert() {
        super.awakeFromInsert()

        // Initialize lastModifiedDate
        lastModifiedDate = Date()

        // If userID is not set, create a placeholder based on username
        // This happens when we only know the username (e.g., message recipients in Sent folder)
        // The real userID will be updated when we encounter this user in a context where we have their ID
        if userID == nil || userID.isEmpty {
            if let name = username, !name.isEmpty {
                // Create a deterministic placeholder ID based on username
                // Prefix with "unknown-" to indicate this is a placeholder
                userID = "unknown-\(name.lowercased().replacingOccurrences(of: " ", with: "_"))"
            } else {
                // Fallback to a UUID if we don't even have a username
                userID = "unknown-\(UUID().uuidString)"
            }
        }
    }
}

extension User {
    public var avatarURL: URL? {
        return customTitleHTML.flatMap(extractAvatarURL)
    }
}

// TODO: this is very stupid, just handle it during scraping
public func extractAvatarURL(fromCustomTitleHTML customTitleHTML: String) -> URL? {
    let document = HTMLDocument(string: customTitleHTML)
    let img = document.firstNode(matchingSelector: "div > img:first-child") ??
        document.firstNode(matchingSelector: "body > img:first-child") ??
        document.firstNode(matchingSelector: "a > img:first-child")

    let src = img?["data-cfsrc"] ?? img?["src"]
    return src.flatMap { URL(string: $0) }
}

@objc(UserKey)
public final class UserKey: AwfulObjectKey {
    @objc public let userID: String
    @objc let username: String?
    
    public init(userID: String, username: String?) {
        precondition(!userID.isEmpty)
        
        self.userID = userID
        self.username = username
        super.init(entityName: User.entityName)
    }
    
    public required init?(coder: NSCoder) {
        userID = coder.decodeObject(forKey: userIDKey) as! String
        username = coder.decodeObject(forKey: usernameKey) as! String?
        super.init(coder: coder)
    }
    
    override var keys: [String] {
        return [userIDKey, usernameKey]
    }
    
    public override func isEqual(_ object: Any?) -> Bool {
        if let other = object as? UserKey {
            return other.userID == userID
        }
        return false
    }
    
    public override var hash: Int {
        return entityName.hash ^ userID.hash
    }
}
private let userIDKey = "userID"
private let usernameKey = "username"
