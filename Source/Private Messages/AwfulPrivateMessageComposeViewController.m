//
//  AwfulPrivateMessageComposeViewController.m
//  Awful
//
//  Created by Nolan Waite on 2013-02-26.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPrivateMessageComposeViewController.h"
#import "AwfulComposeViewControllerSubclass.h"
#import "SVProgressHUD.h"

@interface AwfulPrivateMessageComposeViewController ()

@property (nonatomic) AwfulPrivateMessage *regardingMessage;

@end


@implementation AwfulPrivateMessageComposeViewController

- (void)didTapSend
{
    [self prepareToSendMessage];
}

- (void)send:(NSString *)messageBody
{
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

#pragma mark - AwfulComposeViewController

- (void)willTransitionToState:(AwfulComposeViewControllerState)state
{
    if (state == AwfulComposeViewControllerStateReady) {
        self.textView.userInteractionEnabled = YES;
        [self.textView becomeFirstResponder];
    } else {
        self.textView.userInteractionEnabled = NO;
        [self.textView resignFirstResponder];
    }
    
    if (state == AwfulComposeViewControllerStateUploadingImages) {
        [SVProgressHUD showWithStatus:@"Uploading images…"];
    } else if (state == AwfulComposeViewControllerStateSending) {
        [SVProgressHUD showWithStatus:@"Sending…"];
    } else if (state == AwfulComposeViewControllerStateError) {
        [SVProgressHUD dismiss];
    }
}

#pragma mark - UIViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) return nil;
    self.title = @"Private Message";
    self.sendButton.target = self;
    self.sendButton.action = @selector(didTapSend);
    return self;
}

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
