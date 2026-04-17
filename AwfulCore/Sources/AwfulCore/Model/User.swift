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

        lastModifiedDate = Date()

        // When we only know the username (e.g. message recipients in the Sent folder)
        // we still need a stable userID. Generate a placeholder that can be reconciled
        // once we encounter the same user in a context where we have their real ID.
        if userID.isEmpty {
            if let name = username, !name.isEmpty {
                userID = "\(User.placeholderIDPrefix)\(name.lowercased().replacingOccurrences(of: " ", with: "_"))"
            } else {
                userID = "\(User.placeholderIDPrefix)\(UUID().uuidString)"
            }
        }
    }

    static let placeholderIDPrefix = "unknown-"

    /// True while this user's `userID` is a synthetic placeholder generated from its username.
    public var hasPlaceholderID: Bool { userID.hasPrefix(User.placeholderIDPrefix) }
}

extension User {
    public var avatarURL: URL? {
        return customTitleHTML.flatMap(extractAvatarURL)
    }

    /// Folds any placeholder `User` rows that share this user's username into `self`.
    ///
    /// Call after assigning a real `userID` to a user (e.g. after scraping their profile or a
    /// post that identifies them). Placeholders are created by the Sent-folder PM scrape when
    /// only a recipient's username is known; without this step they would linger in Core Data
    /// indefinitely, accumulating duplicates alongside the real `User` row.
    func absorbPlaceholders() {
        guard let context = managedObjectContext,
              let username, !username.isEmpty,
              !hasPlaceholderID
        else { return }

        let placeholders = User.fetch(in: context) {
            $0.predicate = NSPredicate(
                format: "%K = %@ AND %K BEGINSWITH %@ AND self != %@",
                #keyPath(User.username), username,
                #keyPath(User.userID), User.placeholderIDPrefix,
                self
            )
        }
        guard !placeholders.isEmpty else { return }

        for placeholder in placeholders {
            receivedPrivateMessages.formUnion(placeholder.receivedPrivateMessages)
            sentPrivateMessages.formUnion(placeholder.sentPrivateMessages)
            posts.formUnion(placeholder.posts)
            threads.formUnion(placeholder.threads)
            threadFilters.formUnion(placeholder.threadFilters)
            announcements.formUnion(placeholder.announcements)
            context.delete(placeholder)
        }
    }
}

// TODO: this is very stupid, just handle it during scraping
public func extractAvatarURL(fromCustomTitleHTML customTitleHTML: String) -> URL? {
    let document = HTMLDocument(string: customTitleHTML)
    let img = document.firstNode(matchingParsedSelector: .cached("div > img:first-of-type")) ??
        document.firstNode(matchingParsedSelector: .cached("body > img:first-of-type")) ??
        document.firstNode(matchingParsedSelector: .cached("a > img:first-of-type"))

    let src = img?["data-cfsrc"] ?? img?["src"]
    return src.flatMap { URL(string: $0) }
}

@objc(UserKey)
public final class UserKey: AwfulObjectKey, @unchecked Sendable {
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
