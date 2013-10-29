//  AwfulNewPrivateMessageViewController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulComposeTextViewController.h"
#import "AwfulModels.h"

/**
 * An AwfulNewPrivateMessageViewController is for writing private messages.
 */
@interface AwfulNewPrivateMessageViewController : AwfulComposeTextViewController

/**
 * Returns an initialized AwfulNewPrivateMessageViewController. This is one of three designated initializers.
 */
- (id)initWithRecipient:(AwfulUser *)recipient;

@property (readonly, strong, nonatomic) AwfulUser *recipient;

/**
 * Returns an AwfulNewPrivateMessageViewController initialized as a reply. This is one of three designated initializers.
 *
 * @param regardingMessage The message to reply to.
 * @param initialContents  The initial BBcode contents of the message.
 */
- (id)initWithRegardingMessage:(AwfulPrivateMessage *)regardingMessage initialContents:(NSString *)initialContents;

@property (readonly, strong, nonatomic) AwfulPrivateMessage *regardingMessage;

/**
 * Returns an AwfulNewPrivateMessageViewController initialized as a forward. This is one of three designated initializers.
 *
 * @param forwardingMessage The message to forward.
 * @param initialContents   The initial BBcode contents of the message.
 */
- (id)initWithForwardingMessage:(AwfulPrivateMessage *)forwardingMessage initialContents:(NSString *)initialContents;

@property (readonly, strong, nonatomic) AwfulPrivateMessage *forwardingMessage;

@property (readonly, copy, nonatomic) NSString *initialContents;

@end
