//  AwfulPrivateMessageViewModel.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <Foundation/Foundation.h>
#import "AwfulModels.h"

/**
 * An AwfulPrivateMessageViewModel helps render a private message in an AwfulPostsView.
 */
@interface AwfulPrivateMessageViewModel : NSObject

/**
 * Designated initializer.
 */
- (id)initWithPrivateMessage:(AwfulPrivateMessage *)privateMessage;

/**
 * Keys not described below are forwarded to a private message, making them available to the renderer.
 */
@property (readonly, strong, nonatomic) AwfulPrivateMessage *privateMessage;

/**
 * The CSS for the message.
 */
@property (copy, nonatomic) NSString *stylesheet;

/**
 * Returns "ipad" when run on an iPad, otherwise "iphone".
 */
@property (readonly, copy, nonatomic) NSString *userInterfaceIdiom;

/**
 * The author's avatar URL if it is to be shown.
 */
@property (readonly, strong, nonatomic) NSURL *visibleAvatarURL;

/**
 * The author's avatar URL if it is to be hidden.
 */
@property (readonly, strong, nonatomic) NSURL *hiddenAvatarURL;

/**
 * The contents of the message, modified per the user's settings for loading images etc.
 */
@property (readonly, copy, nonatomic) NSString *HTMLContents;

/**
 * A formatter suitable for a user's regdate.
 */
@property (readonly, strong, nonatomic) NSDateFormatter *regDateFormat;

/**
 * A formatter suitable for the message's send date.
 */
@property (readonly, strong, nonatomic) NSDateFormatter *sentDateFormat;

/**
 * JavaScript used in rendering.
 */
@property (readonly, copy, nonatomic) NSString *javascript;

@end
