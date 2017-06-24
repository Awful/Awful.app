//  PrivateMessagePersistence.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

internal extension PrivateMessageFolderScrapeResult {
    func upsert(into context: NSManagedObjectContext) throws -> [PrivateMessage] {
        var existingMessages: [PrivateMessageID: PrivateMessage] = [:]
        do {
            let request = NSFetchRequest<PrivateMessage>(entityName: PrivateMessage.entityName())
            let messageIDs = self.messages.map { $0.id.rawValue }
            request.predicate = NSPredicate(format: "%K IN %@", #keyPath(PrivateMessage.messageID), messageIDs)
            request.returnsObjectsAsFaults = false

            for message in try context.fetch(request) {
                guard let id = PrivateMessageID(rawValue: message.messageID) else { continue }
                existingMessages[id] = message
            }
        }

        var threadTags: [String: ThreadTag] = [:]
        do {
            let request = NSFetchRequest<ThreadTag>(entityName: ThreadTag.entityName())
            let imageNames = self.messages
                .flatMap { $0.iconImage }
                .map { $0.deletingPathExtension().lastPathComponent }
            request.predicate = NSPredicate(format: "%K IN %@", #keyPath(ThreadTag.imageName), imageNames)
            request.returnsObjectsAsFaults = false

            for threadTag in try context.fetch(request) {
                guard let imageName = threadTag.imageName else { continue }
                threadTags[imageName] = threadTag
            }
        }

        var messages: [PrivateMessage] = []

        for rawMessage in self.messages {
            let message = existingMessages[rawMessage.id]
                ?? PrivateMessage.insertIntoManagedObjectContext(context: context)
            rawMessage.update(message)

            let threadTag: ThreadTag?
            if let imageName = rawMessage.iconImage.map(ThreadTag.imageName) {
                if let existing = threadTags[imageName] {
                    threadTag = existing
                }
                else {
                    let newTag = ThreadTag.insertIntoManagedObjectContext(context: context)
                    newTag.imageName = imageName
                    threadTags[imageName] = newTag
                    threadTag = newTag
                }
            }
            else {
                threadTag = nil
            }
            if threadTag != message.threadTag {
                message.threadTag = threadTag
            }

            messages.append(message)
        }

        return messages
    }
}

private extension PrivateMessageFolderScrapeResult.Message {
    func update(_ message: PrivateMessage) {
        if hasBeenSeen != message.seen { message.seen = hasBeenSeen }
        if id.rawValue != message.messageID { message.messageID = id.rawValue }
        if !senderUsername.isEmpty, senderUsername != message.rawFromUsername { message.rawFromUsername = senderUsername }
        if let sentDate = sentDate, sentDate != message.sentDate { message.sentDate = sentDate }
        if !subject.isEmpty, subject != message.subject { message.subject = subject }
        if wasForwarded != message.forwarded { message.forwarded = wasForwarded }
        if wasRepliedTo != message.replied { message.replied = wasRepliedTo }
    }
}


internal extension PrivateMessageScrapeResult {
    func update(_ message: PrivateMessage) {
        if body != message.innerHTML { message.innerHTML = body }
        if hasBeenSeen != message.seen { message.seen = hasBeenSeen }
        if privateMessageID.rawValue != message.messageID { message.messageID = privateMessageID.rawValue }
        if let sentDate = sentDate, sentDate != message.sentDate { message.sentDate = sentDate }
        if subject != message.subject { message.subject = subject }
        if wasForwarded != message.forwarded { message.forwarded = wasForwarded }
        if wasRepliedTo != message.replied { message.replied = wasRepliedTo }
    }

    func upsert(into context: NSManagedObjectContext) throws -> PrivateMessage {
        let request = NSFetchRequest<PrivateMessage>(entityName: PrivateMessage.entityName())
        request.predicate = NSPredicate(format: "%K = %@", #keyPath(PrivateMessage.messageID), privateMessageID.rawValue)
        request.returnsObjectsAsFaults = false

        let message = try context.fetch(request).first
            ?? PrivateMessage.insertIntoManagedObjectContext(context: context)

        let from = author.flatMap { try? $0.upsert(into: context) }
        if from != message.from { message.from = from }

        update(message)

        return message
    }
}
