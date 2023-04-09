//  Profile.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

import CoreData

@objc(Profile)
public class Profile: AwfulManagedObject, Managed {
    public static var entityName: String { "Profile" }

    @NSManaged public var aboutMe: String?
    @NSManaged public var aimName: String?
    @NSManaged private var primitiveGender: String?
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

    public var gender: Gender? {
        get {
            willAccessValue(forKey: "gender")
            defer { didAccessValue(forKey: "gender") }
            return primitiveGender.flatMap { Gender(rawValue: $0) }
        }
        set {
            willChangeValue(forKey: "gender")
            defer { didChangeValue(forKey: "gender") }
            primitiveGender = newValue?.rawValue
        }
    }

    /// Genders available for selection on the Something Awful Forums.
    public enum Gender: String {
        case female = "female"
        case male = "male"
        case porpoise = "porpoise"
    }
}
