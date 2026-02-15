//  PrivateMessageFolder.swift
//
//  Copyright 2025 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

@objc(PrivateMessageFolder)
public class PrivateMessageFolder: AwfulManagedObject, Managed {
    public static var entityName: String { "PrivateMessageFolder" }

    @NSManaged public var folderID: String
    @NSManaged public var folderType: String
    @NSManaged public var name: String
    @NSManaged public var messages: Set<PrivateMessage>

    public var isInbox: Bool {
        folderID == "0"
    }

    public var isSent: Bool {
        folderID == "-1"
    }

    public var isCustom: Bool {
        !isInbox && !isSent
    }

    public override func awakeFromInsert() {
        super.awakeFromInsert()

        // Initialize required string properties with empty values
        folderID = ""
        folderType = ""
        name = ""
    }
}

@objc(PrivateMessageFolderKey)
public final class PrivateMessageFolderKey: AwfulObjectKey {
    @objc public let folderID: String

    public init(folderID: String) {
        self.folderID = folderID
        super.init(entityName: PrivateMessageFolder.entityName)
    }

    public required init?(coder: NSCoder) {
        guard let id = coder.decodeObject(forKey: folderIDKey) as? String else {
            return nil
        }
        folderID = id
        super.init(coder: coder)
    }

    override var keys: [String] {
        return [folderIDKey]
    }
}
private let folderIDKey = "folderID"
