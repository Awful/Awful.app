//  User.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@objc(User)
public class User: AwfulManagedObject {
    @NSManaged public var administrator: Bool
    @NSManaged var authorClasses: String?
    @NSManaged public var canReceivePrivateMessages: Bool
    @NSManaged public var customTitleHTML: String?
    @NSManaged var lastModifiedDate: NSDate
    @NSManaged public var moderator: Bool
    @NSManaged public var regdate: NSDate?
    @NSManaged public var userID: String
    @NSManaged public var username: String?
    
    @NSManaged var posts: NSMutableSet /* Post */
    @NSManaged var profile: Profile?
    @NSManaged var receivedPrivateMessages: NSMutableSet /* PrivateMessage via to */
    @NSManaged var sentPrivateMessages: NSMutableSet /* PrivateMessage via from */
    @NSManaged var threadFilters: NSMutableSet /* ThreadFilter */
    @NSManaged var threads: NSMutableSet /* Thread */
    
    override var objectKey: UserKey {
        return UserKey(userID: userID, username: username)
    }
}

extension User {
    var avatarURL: NSURL? {
        if let HTML = customTitleHTML {
            if let element = avatarImageElement(customTitleHTML: HTML) {
                return NSURL(string: element.objectForKeyedSubscript("src") as! String!)
            }
        }
        return nil
    }
}

private func avatarImageElement(customTitleHTML HTML: String) -> HTMLElement? {
    let document = HTMLDocument(string: HTML)
    return document.firstNodeMatchingSelector("div > img:first-child") ??
        document.firstNodeMatchingSelector("body > img:first-child") ??
        document.firstNodeMatchingSelector("a > img:first-child")
}

final class UserKey: AwfulObjectKey {
    let userID: String
    let username: String?
    
    init(userID: String, username: String?) {
        precondition(!userID.isEmpty)
        
        self.userID = userID
        self.username = username
        super.init(entityName: User.entityName())
    }
    
    required init(coder: NSCoder) {
        userID = coder.decodeObjectForKey(userIDKey) as! String
        username = coder.decodeObjectForKey(usernameKey) as! String?
        super.init(coder: coder)
    }
    
    override var keys: [String] {
        return [userIDKey, usernameKey]
    }
    
    override func isEqual(object: AnyObject?) -> Bool {
        if let other = object as? UserKey {
            return other.userID == userID
        }
        return false
    }
    
    override var hash: Int {
        return entityName.hash ^ userID.hash
    }
}
private let userIDKey = "userID"
private let usernameKey = "username"

func nilIfEmpty(s: String!) -> String? {
    if s != nil && s.isEmpty {
        return nil
    }
    return s
}
