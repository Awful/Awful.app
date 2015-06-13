//  MessageComposeViewController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "ComposeTextViewController.h"
@import AwfulCore;

/**
 * A MessageComposeViewController is for writing private messages.
 */
@interface MessageComposeViewController : ComposeTextViewController

/**
 * Returns an initialized AwfulNewPrivateMessageViewController. This is one of three designated initializers.
 */
- (instancetype)initWithRecipient:(User *)recipient;

@property (readonly, strong, nonatomic) User *recipient;

/**
 * Returns an AwfulNewPrivateMessageViewController initialized as a reply. This is one of three designated initializers.
 *
 * @param regardingMessage The message to reply to.
 * @param initialContents  The initial BBcode contents of the message.
 */
- (instancetype)initWithRegardingMessage:(PrivateMessage *)regardingMessage initialContents:(NSString *)initialContents;

@property (readonly, strong, nonatomic) PrivateMessage *regardingMessage;

/**
 * Returns an AwfulNewPrivateMessageViewController initialized as a forward. This is one of three designated initializers.
 *
 * @param forwardingMessage The message to forward.
 * @param initialContents   The initial BBcode contents of the message.
 */
- (instancetype)initWithForwardingMessage:(PrivateMessage *)forwardingMessage initialContents:(NSString *)initialContents;

@property (readonly, strong, nonatomic) PrivateMessage *forwardingMessage;

@property (readonly, copy, nonatomic) NSString *initialContents;

@end
