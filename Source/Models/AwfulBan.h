//  AwfulBan.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;
@class Post;
@class User;

typedef NS_ENUM(NSInteger, AwfulPunishment) {
    AwfulPunishmentUnknown = 0,
    AwfulPunishmentProbation,
    AwfulPunishmentBan,
    AwfulPunishmentAutoban,
    AwfulPunishmentPermaban,
};

/**
 * An AwfulBan is a single entry in the Leper's Colony, be it ban, permaban, or probation.
 *
 * AwfulBan objects are not subclasses of NSManagedObject.
 */
@interface AwfulBan : NSObject

@property (strong, nonatomic) User *user;

@property (strong, nonatomic) Post *post;

@property (copy, nonatomic) NSString *reasonHTML;

@property (assign, nonatomic) AwfulPunishment punishment;

@property (strong, nonatomic) NSDate *date;

@property (strong, nonatomic) User *requester;

@property (strong, nonatomic) User *approver;

@end
