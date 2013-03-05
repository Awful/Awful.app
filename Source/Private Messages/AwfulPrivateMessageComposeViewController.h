//
//  AwfulPrivateMessageComposeViewController.h
//  Awful
//
//  Created by Nolan Waite on 2013-02-26.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulComposeViewController.h"
#import "AwfulModels.h"
@protocol AwfulPrivateMessageComposeViewControllerDelegate;

@interface AwfulPrivateMessageComposeViewController : AwfulComposeViewController

@property (weak, nonatomic) id <AwfulPrivateMessageComposeViewControllerDelegate> delegate;

- (void)setRecipient:(NSString *)recipient;
- (void)setSubject:(NSString *)subject;
- (void)setPostIcon:(NSString *)postIcon;
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

// Sent after successfully sending a reply.
- (void)privateMessageComposeController:(AwfulPrivateMessageComposeViewController *)controller
                      didReplyToMessage:(AwfulPrivateMessage *)message;

// Sent if the user cancels sending any kind of message.
- (void)privateMessageComposeControllerDidCancel:(AwfulPrivateMessageComposeViewController *)controller;

@end
