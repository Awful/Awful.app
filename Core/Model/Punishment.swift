//  Punishment.swift
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

/// An entry in a Rap Sheet or in the Leper's Colony. Does not interact with Core Data.
public class Punishment: NSObject {
    public let date: NSDate
    public let sentence: PunishmentSentence
    public let subject: User
    
    public var approver: User?
    public var post: Post?
    public var reasonHTML: String?
    public var requester: User?
    
    public init(date: NSDate, sentence: PunishmentSentence, subject: User) {
        self.date = date
        self.sentence = sentence
        self.subject = subject
        super.init()
    }
    
    public override func isEqual(object: AnyObject?) -> Bool {
        if let other = object as? Punishment {
            return other.date == date && other.sentence == sentence && other.subject == subject
        }
        return false
    }
    
    public override var hash: Int {
        return date.hash ^ subject.hash
    }
}
