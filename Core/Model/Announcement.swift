//  Announcement.swift
//
//  Copyright 2017 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

/**
 Announcements are Forums-wide messages shown on the website atop lists of threads.
 
 While the announcements appear on lists of threads (i.e. within individual forums), it appears that the announcements are set globally and always link to `announcement.php?forumid=1` no matter which forum you're currently viewing.
 
 The closest thing we have to a unique ID for announcements is `listIndex`, which sorts in order of appearance on the website.
 */
@objc(Announcement)
public final class Announcement: AwfulManagedObject {
    @NSManaged public var authorCustomTitleHTML: String
    @NSManaged public var authorRegdate: Date?
    @NSManaged public var authorUsername: String
    @NSManaged public var bodyHTML: String
    @NSManaged public var listIndex: Int32
    @NSManaged public var postedDate: Date?
    @NSManaged public var title: String

    @NSManaged public var author: User?
    @NSManaged public var threadTag: ThreadTag?

    public override func awakeFromInsert() {
        super.awakeFromInsert()

        for property in entity.properties {
            guard let attribute = property as? NSAttributeDescription else { continue }
            if !attribute.isOptional, case .stringAttributeType = attribute.attributeType, attribute.defaultValue == nil {
                setPrimitiveValue("", forKey: attribute.name)
            }
        }
    }
}
