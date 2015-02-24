//  NewMessageChecker.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import Foundation;

/// Periodically checks for new private messages in the logged-in user's inbox and posts notifications.
@interface NewMessageChecker : NSObject

/// The number of unread messages found after the last successful check.
@property (readonly, assign, nonatomic) NSInteger unreadCount;

/// Posts an AwfulDidFinishCheckingNewPrivateMessagesNotification.
- (void)decrementUnreadCount;

/// Convenient singleton instance.
+ (instancetype)sharedChecker;

/// Update the unread message count if it's been awhile since the last check. Returns immediately; observe the AwfulNewMessageCheckerUnreadMessageCountDidChange notification for results.
- (void)refreshIfNecessary;

@end

/// Posted whenever the known unread message count changes. The notification's object is the NewMessageChecker, and its userInfo dictionary contains the AwfulNewPrivateMessageCheckerUnreadCountKey.
extern NSString * const NewMessageCheckerUnreadCountDidChangeNotification;

/// An NSNumber of unread messages found in the inbox.
extern NSString * const NewMessageCheckerUnreadCountKey;
