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
    @NSManaged var authorCustomTitleHTML: String
    @NSManaged var authorRegdate: Date?
    @NSManaged var authorUsername: String
    @NSManaged var bodyHTML: String
    @NSManaged var listIndex: Int32
    @NSManaged var postedDate: Date?
    @NSManaged var title: String

    @NSManaged var author: User?
    @NSManaged var threadTag: ThreadTag?
}
