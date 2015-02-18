//  Profile.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@objc(Profile)
public class Profile: AwfulManagedObject {
    @NSManaged public var aboutMe: String?
    @NSManaged public var aimName: String?
    @NSManaged public var gender: String?
    @NSManaged public var homepageURL: NSURL?
    @NSManaged public var icqName: String?
    @NSManaged public var interests: String?
    @NSManaged var lastModifiedDate: NSDate
    @NSManaged public var lastPostDate: NSDate?
    @NSManaged public var location: String?
    @NSManaged public var occupation: String?
    @NSManaged public var postCount: Int32
    @NSManaged public var postRate: String?
    @NSManaged public var profilePictureURL: NSURL?
    @NSManaged public var yahooName: String?

    @NSManaged public var user: User
}
