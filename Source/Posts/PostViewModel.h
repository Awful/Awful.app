//  PostViewModel.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>
#import "AwfulModels.h"
@class Post;

/**
 * A PostViewModel helps to render Post instances.
 */
@interface PostViewModel : NSObject

/**
 * Designated initializer.
 */
- (instancetype)initWithPost:(Post *)post;

@property (readonly, strong, nonatomic) Post *post;

/**
 * An HTML representation of the post's contents, altered according to the current settings.
 */
@property (readonly, copy, nonatomic) NSString *HTMLContents;

/**
 * The post author's avatar URL if they have one and it is to be displayed.
 */
@property (readonly, strong, nonatomic) NSURL *visibleAvatarURL;

/**
 * The post author's avatar URL if they have one and it is to be hidden.
 */
@property (readonly, strong, nonatomic) NSURL *hiddenAvatarURL;

/**
 * How the post's author is special. May contain any combination of: "op", "mod", "admin", "ik".
 */
@property (readonly, copy, nonatomic) NSString *roles;

/**
 * Roles written out for reading by VoiceOver.
 */
@property (readonly, copy, nonatomic) NSString *accessibilityRoles;

/**
 * A formatter suitable for the date the post was written.
 */
@property (readonly, strong, nonatomic) NSDateFormatter *postDateFormat;

/**
 * A formatter suitable for the author's regdate.
 */
@property (readonly, strong, nonatomic) NSDateFormatter *regDateFormat;

#pragma mark Keys forwarded to the post itself

@property (readonly, nonatomic) AwfulUser *author;
@property (readonly, nonatomic) BOOL beenSeen;
@property (readonly, nonatomic) NSDate *postDate;
@property (readonly, nonatomic) NSString *postID;

@end
