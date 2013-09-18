//  AwfulPrivateMessageComposeViewController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulComposeViewController.h"
#import "AwfulModels.h"

@interface AwfulPrivateMessageComposeViewController : AwfulComposeViewController

- (void)setRecipient:(NSString *)recipient;
- (void)setSubject:(NSString *)subject;
- (void)setMessageBody:(NSString *)messageBody;

// If this is a reply to another message, send this to prepopulate the recipient and subject, and
// link the new message as a reply to the regardingMessage.
- (void)setRegardingMessage:(AwfulPrivateMessage *)regardingMessage;

// To forward a message, send this to prepopulate the subject and link the new message as a forward
// of the forwardedMessage.
- (void)setForwardedMessage:(AwfulPrivateMessage *)forwardedMessage;

@end
