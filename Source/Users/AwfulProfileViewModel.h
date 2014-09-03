//  AwfulProfileViewModel.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>
#import "AwfulModels.h"

/**
 * An AwfulProfileViewModel helps render a user's profile.
 */
@interface AwfulProfileViewModel : NSObject

/**
 * Designated initializer.
 */
- (id)initWithUser:(AwfulUser *)user;

@property (readonly, strong, nonatomic) AwfulUser *user;

/**
 * CSS for displaying a profile.
 */
@property (readonly, copy, nonatomic) NSString *stylesheet;

/**
 * Returns "ipad" on iPads and "iphone" otherwise.
 */
@property (readonly, copy, nonatomic) NSString *userInterfaceIdiom;

/**
 * Whether or not the dark theme should apply.
 */
@property (readonly, assign, nonatomic) BOOL dark;

/**
 * A formatter suitable for a regdate.
 */
@property (readonly, strong, nonatomic) NSDateFormatter *regDateFormat;

/**
 * A formatter suitable for a post date.
 */
@property (readonly, strong, nonatomic) NSDateFormatter *lastPostDateFormat;

/**
 * Whether or not the user has any contact information listed.
 */
@property (readonly, assign, nonatomic) BOOL anyContactInfo;

/**
 * Whether or not a private message might be sent.
 */
@property (readonly, assign, nonatomic) BOOL privateMessagesWork;

/**
 * A list of ways to contact the user. Each item responds to -service and -address.
 */
@property (readonly, copy, nonatomic) NSArray *contactInfo;

/**
 * The user's custom title. If that consists of nothing but a line break, returns nil.
 */
@property (readonly, copy, nonatomic) NSString *customTitleHTML;

/**
 * Returns the user's gender, or "porpoise" if none is set.
 */
@property (readonly, copy, nonatomic) NSString *gender;

/**
 * JavaScript used in rendering.
 */
@property (readonly, copy, nonatomic) NSString *javascript;

#pragma mark Keys forwarded to the user

@property (readonly, nonatomic) NSString *aboutMe;
@property (readonly, nonatomic) NSString *aimName;
@property (readonly, nonatomic) NSURL *avatarURL;
@property (readonly, nonatomic) NSURL *homepageURL;
@property (readonly, nonatomic) NSString *icqName;
@property (readonly, nonatomic) NSString *interests;
@property (readonly, nonatomic) NSDate *lastPost;
@property (readonly, nonatomic) NSString *location;
@property (readonly, nonatomic) NSString *occupation;
@property (readonly, nonatomic) int32_t postCount;
@property (readonly, nonatomic) NSString *postRate;
@property (readonly, nonatomic) NSURL *profilePictureURL;
@property (readonly, nonatomic) NSDate *regdate;
@property (readonly, nonatomic) NSString *username;
@property (readonly, nonatomic) NSString *yahooName;

@end
