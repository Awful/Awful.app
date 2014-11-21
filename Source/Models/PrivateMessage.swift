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

final class PrivateMessageKey: AwfulObjectKey {
    let messageID: String
    
    init(messageID: String) {
        self.messageID = messageID
        super.init(entityName: PrivateMessage.entityName())
    }
    
    required init(coder: NSCoder) {
        messageID = coder.decodeObjectForKey(messageIDKey) as String
        super.init(coder: coder)
    }
    
    override var keys: [String] {
        return [messageIDKey]
    }
}
private let messageIDKey = "messageID"

extension PrivateMessage {
    override var objectKey: PrivateMessageKey {
        get { return PrivateMessageKey(messageID: messageID) }
    }
}
