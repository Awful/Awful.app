//  Profile.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@objc(Profile)
class Profile: AwfulManagedObject {

    @NSManaged var aboutMe: String?
    @NSManaged var aimName: String?
    @NSManaged var gender: String?
    @NSManaged var homepageURL: NSURL?
    @NSManaged var icqName: String?
    @NSManaged var interests: String?
    @NSManaged var lastModifiedDate: NSDate
    @NSManaged var lastPostDate: NSDate?
    @NSManaged var location: String?
    @NSManaged var occupation: String?
    @NSManaged var postCount: Int32
    @NSManaged var postRate: String?
    @NSManaged var profilePictureURL: NSURL?
    @NSManaged var yahooName: String?

    @NSManaged var user: User
}
