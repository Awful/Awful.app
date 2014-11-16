//  AwfulNewMessageChecker.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;

/**
 * An AwfulNewMessageChecker periodically checks for new private messages in the logged-in user's inbox.
 */
@interface AwfulNewMessageChecker : NSObject

/**
 * The number of unread messages found after the last successful check.
 */
@property (readonly, assign, nonatomic) NSInteger unreadMessageCount;

/**
 * A singleton instance created at app launch.
 */
+ (instancetype)checker;

/**
 * Update the unread message count if it's been awhile since the last check.
 */
- (void)refreshIfNecessary;

@end

/**
 * Posted after learning how many new messages there are. The userInfo dictionary contains the AwfulNewPrivateMessageCountKey.
 */
extern NSString * const AwfulDidFinishCheckingNewPrivateMessagesNotification;

/**
 * An NSNumber of unread messages found in the inbox.
 */
extern NSString * const AwfulNewPrivateMessageCountKey;
