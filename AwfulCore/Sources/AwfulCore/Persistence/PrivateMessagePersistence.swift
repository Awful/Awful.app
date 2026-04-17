//  PrivateMessagePersistence.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

internal extension PrivateMessageFolderScrapeResult {
    func upsert(
        into context: NSManagedObjectContext,
        folderID: String = "0"
    ) throws -> [PrivateMessage] {
        var existingMessages: [PrivateMessageID: PrivateMessage] = [:]
        do {
            let messages = PrivateMessage.fetch(in: context) {
                $0.predicate = .init("\(\PrivateMessage.messageID) IN \(self.messages.map { $0.id.rawValue })")
                $0.returnsObjectsAsFaults = false
            }
            for message in messages {
                guard let id = PrivateMessageID(rawValue: message.messageID) else { continue }
                existingMessages[id] = message
            }
        }

        var threadTags: [String: ThreadTag] = [:]
        do {
            let tags = ThreadTag.fetch(in: context) {
                let imageNames = self.messages
                    .compactMap { $0.iconImage }
                    .map { $0.deletingPathExtension().lastPathComponent }
                $0.predicate = .init("\(\ThreadTag.imageName) IN \(imageNames)")
                $0.returnsObjectsAsFaults = false
            }
            for threadTag in tags {
                guard let imageName = threadTag.imageName else { continue }
                threadTags[imageName] = threadTag
            }
        }

        let folder = PrivateMessageFolder.findOrCreate(in: context, matching: .init("\(\PrivateMessageFolder.folderID) = \(folderID)")) {
            $0.folderID = folderID
            switch folderID {
            case "0":
                $0.folderType = "inbox"
                $0.name = "Inbox"
            case "-1":
                $0.folderType = "sent"
                $0.name = "Sent Items"
            default:
                $0.folderType = "custom"
                $0.name = self.folder?.name ?? "Folder"
            }
        }

        var messages: [PrivateMessage] = []

        let isSentFolder = folderID == "-1"
        // Key matches Settings.username from AwfulSettings.
        let currentUsername = isSentFolder
            ? UserDefaults.standard.string(forKey: "username").flatMap { $0.isEmpty ? nil : $0 }
            : nil

        for rawMessage in self.messages {
            let message: PrivateMessage
            if let existing = existingMessages[rawMessage.id] {
                message = existing
            } else {
                message = PrivateMessage.insert(into: context)
                message.messageID = rawMessage.id.rawValue
            }
            rawMessage.update(message, isSentFolder: isSentFolder)

            message.lastModifiedDate = Date()

            if message.folder != folder {
                message.folder = folder
            }

            if message.isSent != isSentFolder {
                message.isSent = isSentFolder
            }

            // In the Sent folder the scraper has no "from" user — we are always the sender.
            if isSentFolder, message.from == nil, let currentUsername {
                let currentUser = User.findOrCreate(in: context, matching: NSPredicate(format: "%K = %@", #keyPath(User.username), currentUsername)) {
                    $0.username = currentUsername
                }
                message.from = currentUser
            }

            let threadTag: ThreadTag?
            if let imageName = rawMessage.iconImage.map(ThreadTag.imageName) {
                if let existing = threadTags[imageName] {
                    threadTag = existing
                }
                else {
                    let newTag = ThreadTag.insert(into: context)
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
    func update(_ message: PrivateMessage, isSentFolder: Bool = false) {
        if hasBeenSeen != message.seen { message.seen = hasBeenSeen }
        if id.rawValue != message.messageID { message.messageID = id.rawValue }

        // In the Sent folder, the scraper reports the recipient in senderUsername.
        if isSentFolder {
            if !senderUsername.isEmpty, let context = message.managedObjectContext {
                let user = User.findOrCreate(in: context, matching: NSPredicate(format: "%K = %@", #keyPath(User.username), senderUsername)) {
                    $0.username = senderUsername
                }
                message.to = user
            }
        } else if !senderUsername.isEmpty, senderUsername != message.rawFromUsername {
            message.rawFromUsername = senderUsername
        }

        if let sentDate = sentDate, sentDate != message.sentDate { message.sentDate = sentDate }
        if let sentDateRaw = sentDateRaw, sentDateRaw != message.sentDateRaw { message.sentDateRaw = sentDateRaw }
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
        if let sentDateRaw = sentDateRaw, sentDateRaw != message.sentDateRaw { message.sentDateRaw = sentDateRaw }
        if subject != message.subject { message.subject = subject }
        if wasForwarded != message.forwarded { message.forwarded = wasForwarded }
        if wasRepliedTo != message.replied { message.replied = wasRepliedTo }
    }

    func upsert(
        into context: NSManagedObjectContext
    ) throws -> PrivateMessage {
        let message = PrivateMessage.findOrCreate(in: context, matching: .init("\(\PrivateMessage.messageID) = \(privateMessageID.rawValue)")) {
            $0.messageID = privateMessageID.rawValue
        }
        let from = author.flatMap { try? $0.upsert(into: context) }
        if from != message.from { message.from = from }

        update(message)

        message.lastModifiedDate = Date()

        return message
    }
}
