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

extension User {
    class func firstOrNewUserWithID(userID: String?, username: String?, inManagedObjectContext context: NSManagedObjectContext) -> User {
        assert(!(empty(userID) && empty(username)), "need either a userID or a username")
        
        var subpredicates = [NSPredicate]()
        if !empty(userID) {
            subpredicates.append(NSPredicate(format: "userID = %@", userID!)!)
        }
        if !empty(username) {
            subpredicates.append(NSPredicate(format: "username = %@", username!)!)
        }
        let predicate = NSCompoundPredicate.orPredicateWithSubpredicates(subpredicates)
        var user = User.fetchArbitraryInManagedObjectContext(context, matchingPredicate: predicate)
        if user == nil {
            user = User.insertInManagedObjectContext(context)
        }
        if !empty(userID) {
            user.userID = userID
        }
        if !empty(username) {
            user.username = username
        }
        return user
    }
}

private func empty(string: String?) -> Bool {
    if let string = string {
        return string.isEmpty
    }
    return true
}
