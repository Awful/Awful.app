//  PrivateMessage.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

@objc(PrivateMessage)
public class PrivateMessage: AwfulManagedObject {
    @NSManaged public var forwarded: Bool
    @NSManaged public var innerHTML: String?
    @NSManaged var lastModifiedDate: Date
    @NSManaged public var messageID: String
    // When we scrape a folder of messages, we can't get at the "from" user's userID. rawFromUsername holds this unhelpful bit of data until we learn of the user's ID and can use the `from` relationship.
    @NSManaged public var rawFromUsername: String?
    @NSManaged public var replied: Bool
    @NSManaged public var seen: Bool
    @NSManaged public var sentDate: Date?
    @NSManaged public var subject: String?
    
    @NSManaged internal var primitiveFrom: User? /* via sentPrivateMessages */
    @NSManaged public var threadTag: ThreadTag?
    @NSManaged var to: User? /* via receivedPrivateMessages */
}

extension PrivateMessage {
    public var from: User? {
        get {
            willAccessValue(forKey: "from")
            let from = primitiveFrom
            didAccessValue(forKey: "from")
            return from
        }
        set {
            willChangeValue(forKey: "from")
            willChangeValue(forKey: "rawFromUsername")
            primitiveFrom = newValue
            rawFromUsername = nil
            didChangeValue(forKey: "rawFromUsername")
            didChangeValue(forKey: "from")
        }
    }
    
    public var fromUsername: String? {
        return from?.username ?? rawFromUsername
    }
}

@objc(PrivateMessageKey)
public final class PrivateMessageKey: AwfulObjectKey {
    @objc public let messageID: String
    
    public init(messageID: String) {
        self.messageID = messageID
        super.init(entityName: PrivateMessage.entityName())
    }
    
    public required init?(coder: NSCoder) {
        messageID = coder.decodeObject(forKey: messageIDKey) as! String
        super.init(coder: coder)
    }
    
    override var keys: [String] {
        return [messageIDKey]
    }
}
private let messageIDKey = "messageID"

extension PrivateMessage {
    public override var objectKey: PrivateMessageKey {
        get { return PrivateMessageKey(messageID: messageID) }
    }
}
