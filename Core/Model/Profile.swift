//  Profile.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import Foundation

@objc(Profile)
public class Profile: AwfulManagedObject {
    @NSManaged public var aboutMe: String?
    @NSManaged public var aimName: String?
    @NSManaged public var gender: String?
    @NSManaged public var homepageURL: URL?
    @NSManaged public var icqName: String?
    @NSManaged public var interests: String?
    @NSManaged var lastModifiedDate: Date
    @NSManaged public var lastPostDate: Date?
    @NSManaged public var location: String?
    @NSManaged public var occupation: String?
    @NSManaged public var postCount: Int32
    @NSManaged public var postRate: String?
    @NSManaged public var profilePictureURL: URL?
    @NSManaged public var yahooName: String?

    @NSManaged public var user: User
}
