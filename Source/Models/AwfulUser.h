//  AwfulUser.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulModels.h"
#import "AwfulParsing.h"

/**
 * An AwfulUser post post posts.
 */
@interface AwfulUser : AwfulManagedObject

/**
 * A user-supplied paragraph that describes them. Default is some vaguely insulting thing.
 */
@property (copy, nonatomic) NSString *aboutMe;

/**
 * YES if the user is an administrator, otherwise NO.
 */
@property (assign, nonatomic) BOOL administrator;

/**
 * A user-supplied AOL Instant Messenger username.
 */
@property (copy, nonatomic) NSString *aimName;

/**
 * YES if the user can receive a private message, otherwise NO.
 */
@property (assign, nonatomic) BOOL canReceivePrivateMessages;

/**
 * The user's custom title as raw HTML.
 */
@property (copy, nonatomic) NSString *customTitleHTML;

/**
 * The user's gender, one of "female", "male", "porpoise".
 */
@property (copy, nonatomic) NSString *gender;

/**
 * A user-supplied URL to their homepage.
 */
@property (strong, nonatomic) NSURL *homepageURL;

/**
 * A user-supplied ICQ name or number.
 */
@property (copy, nonatomic) NSString *icqName;

/**
 * A brief user-supplied description of what interests them.
 */
@property (copy, nonatomic) NSString *interests;

/**
 * The date when the user's most recent post was written.
 */
@property (strong, nonatomic) NSDate *lastPost;

/**
 * A brief user-supplied description of where they live.
 */
@property (copy, nonatomic) NSString *location;

/**
 * YES if the user is a moderator of any forum, otherwise NO.
 */
@property (assign, nonatomic) BOOL moderator;

/**
 * A brief user-supplied description of their job.
 */
@property (copy, nonatomic) NSString *occupation;

/**
 * The number of posts the user has made. Remember that posts in FYAD count for -1, and some forums may not affect post count.
 */
@property (assign, nonatomic) int32_t postCount;

/**
 * The average number of posts written by the user per day since their registration, probably stored as a decimal number's string value.
 */
@property (copy, nonatomic) NSString *postRate;

/**
 * The URL to the user's profile picture, or nil if they have none.
 */
@property (strong, nonatomic) NSURL *profilePictureURL;

/**
 * When the user created their account.
 */
@property (strong, nonatomic) NSDate *regdate;

/**
 * The user's presumably unique ID.
 */
@property (copy, nonatomic) NSString *userID;

/**
 * The user's name.
 */
@property (copy, nonatomic) NSString *username;

/**
 * A user-supplied Yahoo! Messenger username.
 */
@property (copy, nonatomic) NSString *yahooName;

/**
 * A set of AwfulPost objects representing posts the user has edited.
 */
@property (copy, nonatomic) NSSet *editedPosts;

/**
 * A set of AwfulPost objects representing posts the user has written.
 */
@property (copy, nonatomic) NSSet *posts;

/**
 * A set of AwfulPrivateMessage objects that the user has received.
 */
@property (copy, nonatomic) NSSet *receivedPrivateMessages;

/**
 * A set of AwfulPrivateMessage objects that the user has sent.
 */
@property (copy, nonatomic) NSSet *sentPrivateMessages;

/**
 * A set of AwfulSingleUserThreadInfo objects storing info about the user.
 */
@property (copy, nonatomic) NSSet *singleUserThreadInfos;

/**
 * A set of AwfulThread objects posted by the user.
 */
@property (copy, nonatomic) NSSet *threads;

/**
 * A URL to the user's avatar image, as derived from the user's customTitle.
 */
@property (readonly, nonatomic) NSURL *avatarURL;

/**
 * Returns an AwfulUser with the given user ID and/or username, inserting one if necessary.
 */
+ (instancetype)firstOrNewUserWithUserID:(NSString *)userID
                                username:(NSString *)username
                  inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

@end
