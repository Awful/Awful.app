//  PrivateMessage.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@objc(PrivateMessage)
class PrivateMessage: AwfulManagedObject {

    @NSManaged var forwarded: Bool
    @NSManaged var innerHTML: String?
    @NSManaged var lastModifiedDate: NSDate
    @NSManaged var messageID: String
    @NSManaged var replied: Bool
    @NSManaged var seen: Bool
    @NSManaged var sentDate: NSDate?
    @NSManaged var subject: String?
    
    @NSManaged var from: User? /* via sentPrivateMessages */
    @NSManaged var threadTag: ThreadTag?
    @NSManaged var to: User? /* via receivedPrivateMessages */
}

class PrivateMessageKey: AwfulObjectKey {
    let messageID: String
    init(messageID: String) {
        self.messageID = messageID
        super.init(entityName: PrivateMessage.entityName())
    }
    required init(coder: NSCoder) {
        messageID = coder.decodeObjectForKey(messageIDKey) as String
        super.init(coder: coder)
    }
    override func encodeWithCoder(coder: NSCoder) {
        super.encodeWithCoder(coder)
        coder.encodeObject(messageID, forKey: messageIDKey)
    }
    override func isEqual(object: AnyObject?) -> Bool {
        if !super.isEqual(object) { return false }
        if let other = object as? PrivateMessageKey {
            return other.messageID == messageID
        } else {
            return false
        }
    }
    override var hash: Int {
        get { return super.hash ^ messageID.hash }
    }
}

private let messageIDKey = "messageID"

extension PrivateMessage {
    override var objectKey: PrivateMessageKey {
        get { return PrivateMessageKey(messageID: messageID) }
    }
    
    class func objectForKey(messageKey: PrivateMessageKey, inManagedObjectContext context: NSManagedObjectContext) -> PrivateMessage {
        if let message = fetchArbitraryInManagedObjectContext(context, matchingPredicate: NSPredicate(format: "messageID = %@", messageKey.messageID)) {
            return message
        } else {
            let message = insertInManagedObjectContext(context)
            message.messageID = messageKey.messageID
            return message
        }
    }
}
