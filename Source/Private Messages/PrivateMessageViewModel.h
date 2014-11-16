//  PrivateMessageViewModel.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;
@class PrivateMessage, User;

/**
 * A PrivateMessageViewModel helps render a private message in an AwfulPostsView.
 */
@interface PrivateMessageViewModel : NSObject

- (instancetype)initWithPrivateMessage:(PrivateMessage *)privateMessage NS_DESIGNATED_INITIALIZER;

@property (readonly, strong, nonatomic) PrivateMessage *privateMessage;

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

/**
 * The current font scale.
 */
@property (readonly, strong, nonatomic) NSNumber *fontScalePercentage;

#pragma mark Keys forwarded to the message

@property (readonly, nonatomic) User *from;
@property (readonly, nonatomic) NSString *messageID;
@property (readonly, nonatomic) BOOL seen;
@property (readonly, nonatomic) NSDate *sentDate;

@end
