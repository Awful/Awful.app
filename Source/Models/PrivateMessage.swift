//  PrivateMessage.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@objc(PrivateMessage)
class PrivateMessage: AwfulManagedObject {

    @NSManaged var forwarded: Bool
    @NSManaged var innerHTML: String?
    @NSManaged var lastModifiedDate: NSDate
    @NSManaged private var primitiveLastModifiedDate: NSDate?
    @NSManaged var messageID: String
    @NSManaged var replied: Bool
    @NSManaged var seen: Bool
    @NSManaged var sentDate: NSDate?
    @NSManaged var subject: String?
    
    @NSManaged var from: AwfulUser? /* via sentPrivateMessages */
    @NSManaged var threadTag: AwfulThreadTag?
    @NSManaged var to: AwfulUser? /* via receivedPrivateMessages */
    
    override func awakeFromInsert() {
        super.awakeFromInsert()
        primitiveLastModifiedDate = NSDate()
    }
}

extension PrivateMessage {
    class func firstOrNewPrivateMessageWithMessageID(messageID: String, inManagedObjectContext context: NSManagedObjectContext) -> PrivateMessage {
        if let message = fetchArbitraryInManagedObjectContext(context, matchingPredicate: NSPredicate(format: "messageID = %@", messageID)) {
            return message
        } else {
            let message = insertInManagedObjectContext(context)
            message.messageID = messageID
            return message
        }
    }
}
