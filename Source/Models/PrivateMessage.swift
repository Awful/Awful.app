//  PrivateMessage.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@objc(PrivateMessage)
public class PrivateMessage: AwfulManagedObject {

    @NSManaged public var forwarded: Bool
    @NSManaged public var innerHTML: String?
    @NSManaged var lastModifiedDate: NSDate
    @NSManaged public var messageID: String
    @NSManaged public var replied: Bool
    @NSManaged public var seen: Bool
    @NSManaged public var sentDate: NSDate?
    @NSManaged public var subject: String?
    
    @NSManaged public var from: User? /* via sentPrivateMessages */
    @NSManaged public var threadTag: ThreadTag?
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
