//  User.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@objc(User)
class User: AwfulManagedObject {

    @NSManaged var aboutMe: String?
    @NSManaged var administrator: Bool
    @NSManaged var aimName: String?
    @NSManaged var authorClasses: String?
    @NSManaged var canReceivePrivateMessages: Bool
    @NSManaged var customTitleHTML: String?
    @NSManaged var gender: String?
    @NSManaged var homepageURL: NSURL?
    @NSManaged var icqName: String?
    @NSManaged var interests: String?
    @NSManaged var lastModifiedDate: NSDate
    @NSManaged var primitiveLastModifiedDate: NSDate?
    @NSManaged var lastPostDate: NSDate?
    @NSManaged var location: String?
    @NSManaged var moderator: Bool
    @NSManaged var occupation: String?
    @NSManaged var postCount: Int32
    @NSManaged var postRate: String?
    @NSManaged var profilePictureURL: NSURL?
    @NSManaged var regdate: NSDate?
    @NSManaged var userID: String?
    @NSManaged var username: String?
    @NSManaged var yahooName: String?
    
    @NSManaged var posts: NSMutableSet /* Post */
    @NSManaged var receivedPrivateMessages: NSMutableSet /* PrivateMessage via to */
    @NSManaged var sentPrivateMessages: NSMutableSet /* PrivateMessage via from */
    @NSManaged var singleUserThreadInfos: NSMutableSet /* SingleUserThreadInfo */
    @NSManaged var threads: NSMutableSet /* Thread */
    
    override func awakeFromInsert() {
        super.awakeFromInsert()
        primitiveLastModifiedDate = NSDate()
    }
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
