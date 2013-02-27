//
//  AwfulPrivateMessageComposeViewController.m
//  Awful
//
//  Created by Nolan Waite on 2013-02-26.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPrivateMessageComposeViewController.h"
#import "AwfulComposeViewControllerSubclass.h"

@interface AwfulPrivateMessageComposeViewController ()

@property (nonatomic) AwfulPrivateMessage *regardingMessage;

@end


@implementation AwfulPrivateMessageComposeViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) return nil;
    self.title = @"Private Message";
    self.sendButton.target = self.cancelButton.target = self;
    self.sendButton.action = @selector(send);
    self.cancelButton.action = @selector(cancel);
    return self;
}

- (void)send
{
    // TODO image uploads
    // TODO actually send
    if (self.regardingMessage) {
        SEL selector = @selector(privateMessageComposeController:didReplyToMessage:);
        if ([self.delegate respondsToSelector:selector]) {
            [self.delegate privateMessageComposeController:self
                                         didReplyToMessage:self.regardingMessage];
        }
    } else {
        SEL selector = @selector(privateMessageComposeControllerDidSendMessage:);
        if ([self.delegate respondsToSelector:selector]) {
            [self.delegate privateMessageComposeControllerDidSendMessage:self];
        }
    }
}

- (void)cancel
{
    if ([self.delegate respondsToSelector:@selector(privateMessageComposeControllerDidCancel:)]) {
        [self.delegate privateMessageComposeControllerDidCancel:self];
    }
}

- (void)setRecipient:(NSString *)recipient
{
    // TODO
}

- (void)setSubject:(NSString *)subject
{
    // TODO
}

- (void)setPostIcon:(NSString *)postIcon
{
    // TODO
}

- (void)setMessageBody:(NSString *)messageBody
{
    self.textView.text = messageBody;
}

- (void)setRegardingMessage:(AwfulPrivateMessage *)regardingMessage
{
    _regardingMessage = regardingMessage;
    // TODO set recipient and subject (and post icon?)
}

#pragma mark - UIViewController

- (void)loadView
{
    self.view = self.textView;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.textView becomeFirstResponder];
}

@end
