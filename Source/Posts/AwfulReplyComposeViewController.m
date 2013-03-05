//
//  AwfulReplyComposeViewController.m
//  Awful
//
//  Created by Sean Berry on 11/21/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulReplyComposeViewController.h"
#import "AwfulComposeViewControllerSubclass.h"
#import "AwfulAlertView.h"
#import "AwfulHTTPClient.h"
#import "AwfulKeyboardBar.h"
#import "AwfulModels.h"
#import "AwfulSettings.h"
#import "AwfulTextView.h"
#import "ImgurHTTPClient.h"
#import "NSString+CollapseWhitespace.h"
#import "SVProgressHUD.h"
#import "UINavigationItem+TwoLineTitle.h"

@interface AwfulReplyComposeViewController () <UIImagePickerControllerDelegate,
                                               UINavigationControllerDelegate,
                                               UIPopoverControllerDelegate>

@property (weak, nonatomic) NSOperation *networkOperation;

@property (nonatomic) AwfulThread *thread;
@property (nonatomic) AwfulPost *post;

@end


@implementation AwfulReplyComposeViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) return nil;
    self.sendButton.target = self;
    self.sendButton.action = @selector(didTapSend);
    self.cancelButton.target = self;
    self.cancelButton.action = @selector(cancel);
    return self;
}

- (void)editPost:(AwfulPost *)post text:(NSString *)text
{
    self.post = post;
    self.thread = nil;
    self.textView.text = text;
    self.title = [post.thread.title stringByCollapsingWhitespace];
    self.navigationItem.titleLabel.text = self.title;
    self.sendButton.title = @"Save";
}

- (void)replyToThread:(AwfulThread *)thread withInitialContents:(NSString *)contents
{
    self.thread = thread;
    self.post = nil;
    self.textView.text = contents;
    self.title = [thread.title stringByCollapsingWhitespace];
    self.navigationItem.titleLabel.text = self.title;
    self.sendButton.title = @"Reply";
}

- (void)didTapSend
{
    if (self.state != AwfulComposeViewControllerStateReady) return;
    [self.networkOperation cancel];
    [self.textView resignFirstResponder];
    self.textView.userInteractionEnabled = NO;
    if ([AwfulSettings settings].confirmBeforeReplying) {
        AwfulAlertView *alert = [AwfulAlertView new];
        alert.title = @"Incoming Forums Superstar";
        alert.message = @"Does my reply offer any significant advice or help "
                         "contribute to the conversation in any fashion?";
        [alert addCancelButtonWithTitle:@"Nope" block:^{
            self.textView.userInteractionEnabled = YES;
            [self.textView becomeFirstResponder];
        }];
        [alert addButtonWithTitle:self.sendButton.title block:^{ [self prepareToSendMessage]; }];
        [alert show];
    } else {
        [self prepareToSendMessage];
    }
}

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
        [SVProgressHUD showWithStatus:self.thread ? @"Replying…" : @"Editing…"
                             maskType:SVProgressHUDMaskTypeClear];
    } else if (state == AwfulComposeViewControllerStateError) {
        [SVProgressHUD dismiss];
    }
}

- (void)send:(NSString *)messageBody
{
    NSOperation *op;
    void (^errorHandler)(NSError*) = ^(NSError *error){
        [SVProgressHUD dismiss];
        [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK" completion:^{
            self.textView.userInteractionEnabled = YES;
        }];
    };
    if (self.thread) {
        op = [[AwfulHTTPClient client] replyToThreadWithID:self.thread.threadID text:messageBody
                                                   andThen:^(NSError *error, NSString *postID)
        {
            if (error) return errorHandler(error);
            [SVProgressHUD showSuccessWithStatus:@"Replied"];
            [self.delegate replyComposeController:self didReplyToThread:self.thread];
        }];
    } else {
        op = [[AwfulHTTPClient client] editPostWithID:self.post.postID text:messageBody
                                              andThen:^(NSError *error)
        {
            if (error) return errorHandler(error);
            [SVProgressHUD showSuccessWithStatus:@"Edited"];
            [self.delegate replyComposeController:self didEditPost:self.post];
        }];
    }
    self.networkOperation = op;
}

- (void)cancel
{
    [super cancel];
    [self.networkOperation cancel];
    if ([SVProgressHUD isVisible]) {
        [SVProgressHUD dismiss];
        self.textView.userInteractionEnabled = YES;
        [self.textView becomeFirstResponder];
    } else {
        [self.delegate replyComposeControllerDidCancel:self];
    }
}

#pragma mark - UIViewController

- (void)loadView
{
    self.view = self.textView;
}

@end
