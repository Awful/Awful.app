//
//  PrivateMessagePersistence.swift
//  Awful
//
//  Created by Nolan Waite on 2017-05-28.
//  Copyright © 2017 Awful Contributors. All rights reserved.
//

import CoreData

internal extension PrivateMessageScrapeResult {
    func upsert(into context: NSManagedObjectContext) throws -> PrivateMessage {
        let request = NSFetchRequest<PrivateMessage>(entityName: PrivateMessage.entityName())
        request.predicate = NSPredicate(format: "%K = %@", #keyPath(PrivateMessage.messageID), privateMessageID.rawValue)
        request.returnsObjectsAsFaults = false

        let message = try context.fetch(request).first
            ?? PrivateMessage.insertIntoManagedObjectContext(context: context)

        if body.rawValue != message.innerHTML { message.innerHTML = body.rawValue }
        let from = author.flatMap { try? $0.upsert(into: context) }
        if from != message.from { message.from = from }
        if hasBeenSeen != message.seen { message.seen = hasBeenSeen }
        if privateMessageID.rawValue != message.messageID { message.messageID = privateMessageID.rawValue }
        if let sentDate = sentDate, sentDate != message.sentDate as Date? { message.sentDate = sentDate as NSDate }
        if subject != message.subject { message.subject = subject }
        if wasForwarded != message.forwarded { message.forwarded = wasForwarded }
        if wasRepliedTo != message.replied { message.replied = wasRepliedTo }

        return message
    }
}
