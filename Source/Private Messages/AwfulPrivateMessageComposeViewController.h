//
//  AwfulPrivateMessageComposeViewController.h
//  Awful
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app
//

#import "AwfulComposeViewController.h"
#import "AwfulModels.h"
@protocol AwfulPrivateMessageComposeViewControllerDelegate;

@interface AwfulPrivateMessageComposeViewController : AwfulComposeViewController

@property (weak, nonatomic) id <AwfulPrivateMessageComposeViewControllerDelegate> delegate;

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


@protocol AwfulPrivateMessageComposeViewControllerDelegate <NSObject>
@optional

// Sent after successfully sending a new message.
- (void)privateMessageComposeControllerDidSendMessage:(AwfulPrivateMessageComposeViewController *)controller;

// Sent if the user cancels the message.
- (void)privateMessageComposeControllerDidCancel:(AwfulPrivateMessageComposeViewController *)controller;

@end
