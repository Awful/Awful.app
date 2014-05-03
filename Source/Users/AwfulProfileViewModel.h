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

/**
 * Keys not described below are forwarded to a user, making them available to the renderer.
 */
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
 * JavaScript libraries used in rendering.
 */
@property (readonly, copy, nonatomic) NSString *JavaScriptLibraries;

@end
