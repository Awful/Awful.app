//  User.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@objc(User)
class User: AwfulManagedObject {

    @NSManaged var administrator: Bool
    @NSManaged var authorClasses: String?
    @NSManaged var canReceivePrivateMessages: Bool
    @NSManaged var customTitleHTML: String?
    @NSManaged var lastModifiedDate: NSDate
    @NSManaged var moderator: Bool
    @NSManaged var regdate: NSDate?
    @NSManaged var userID: String?
    @NSManaged var username: String?
    
    @NSManaged var posts: NSMutableSet /* Post */
    @NSManaged var profile: Profile?
    @NSManaged var receivedPrivateMessages: NSMutableSet /* PrivateMessage via to */
    @NSManaged var sentPrivateMessages: NSMutableSet /* PrivateMessage via from */
    @NSManaged var threadFilters: NSMutableSet /* ThreadFilter */
    @NSManaged var threads: NSMutableSet /* Thread */
}

extension User {
    var avatarURL: NSURL? {
        get {
            if let HTML = customTitleHTML {
                if let element = avatarImageElement(customTitleHTML: HTML) {
                    return NSURL(string: element.objectForKeyedSubscript("src") as String!)
                }
            }
            return nil
        }
    }
}

private func avatarImageElement(customTitleHTML HTML: String) -> HTMLElement? {
    let document = HTMLDocument(string: HTML)
    return document.firstNodeMatchingSelector("div > img:first-child") ??
        document.firstNodeMatchingSelector("body > img:first-child") ??
        document.firstNodeMatchingSelector("a > img:first-child")
}

class UserKey: AwfulObjectKey {
    let userID: String?
    let username: String?
    init(userID: String!, username: String!) {
        assert(!empty(userID) || !empty(username))
        self.userID = userID
        self.username = username
        super.init(entityName: User.entityName())
    }
    required init(coder: NSCoder) {
        userID = coder.decodeObjectForKey(userIDKey) as String?
        username = coder.decodeObjectForKey(usernameKey) as String?
        super.init(coder: coder)
    }
    override func encodeWithCoder(coder: NSCoder) {
        super.encodeWithCoder(coder)
        if let userID = userID {
            coder.encodeObject(userID, forKey: userIDKey)
        }
        if let username = username {
            coder.encodeObject(username, forKey: usernameKey)
        }
    }
    override func isEqual(object: AnyObject?) -> Bool {
        if !super.isEqual(object) { return false }
        if let other = object as? UserKey {
            if userID != nil && other.userID != nil {
                return other.userID! == userID!
            } else if username != nil && other.username != nil {
                return other.username! == username!
            }
        }
        return false
    }
    override class func valuesForKeysInObjectKeys(objectKeys: [AwfulObjectKey]) -> [String: [AnyObject]] {
        var userIDs = [String]()
        var usernames = [String]()
        for key in objectKeys as [UserKey] {
            if let userID = key.userID {
                userIDs.append(userID)
            }
            if let username = key.username {
                usernames.append(username)
            }
        }
        return [
            "userID": userIDs,
            "username": usernames
        ]
    }
}

private let userIDKey = "userID"
private let usernameKey = "username"

extension User {
    override var objectKey: UserKey {
        get { return UserKey(userID: userID, username: username) }
    }
    
    override func applyObjectKey(objectKey: AwfulObjectKey) {
        let objectKey = objectKey as UserKey
        if !empty(objectKey.userID) {
            userID = objectKey.userID
        }
        if !empty(objectKey.username) {
            username = objectKey.username
        }
    }
    
    class func objectForKey(userKey: UserKey, inManagedObjectContext context: NSManagedObjectContext) -> User {
        var subpredicates = [NSPredicate]()
        if !empty(userKey.userID) {
            subpredicates.append(NSPredicate(format: "userID = %@", userKey.userID!)!)
        }
        if !empty(userKey.username) {
            subpredicates.append(NSPredicate(format: "username = %@", userKey.username!)!)
        }
        let predicate = NSCompoundPredicate.orPredicateWithSubpredicates(subpredicates)
        var user = User.fetchArbitraryInManagedObjectContext(context, matchingPredicate: predicate)
        if user == nil {
            user = User.insertInManagedObjectContext(context)
        }
        user.applyObjectKey(userKey)
        return user
    }
}

private func empty(string: String?) -> Bool {
    if let string = string {
        return string.isEmpty
    }
    return true
}
