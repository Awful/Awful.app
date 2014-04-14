//  AwfulPostViewModel.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>
#import "AwfulModels.h"

/**
 * An AwfulPostViewModel helps to render AwfulPost instances.
 */
@interface AwfulPostViewModel : NSObject

/**
 * Designated initializer.
 */
- (id)initWithPost:(AwfulPost *)post;

/**
 * Keys not described below are forwarded to a post, making them available to the renderer.
 */
@property (readonly, strong, nonatomic) AwfulPost *post;

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
@property (readonly, copy, nonatomic) NSArray *roles;

/**
 * A formatter suitable for the date the post was written.
 */
@property (readonly, strong, nonatomic) NSDateFormatter *postDateFormat;

/**
 * A formatter suitable for the author's regdate.
 */
@property (readonly, strong, nonatomic) NSDateFormatter *regDateFormat;

@end
