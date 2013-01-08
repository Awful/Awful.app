//
//  AwfulPMReplyViewController.m
//  Awful
//
//  Created by me on 1/8/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPMComposerViewController.h"
#import "NSString+CollapseWhitespace.h"
#import "UINavigationItem+TwoLineTitle.h"
#import "AwfulSettings.h"
#import "AwfulAlertView.h"
#import "SVProgressHUD.h"
#import "AwfulHTTPClient+PrivateMessages.h"

@interface AwfulPMComposerViewController ()

@end

@implementation AwfulPMComposerViewController

- (void)replyToPrivateMessage:(AwfulPrivateMessage *)message
{
    self.composerTextView.text = message.content;
    self.title = [message.subject stringByCollapsingWhitespace];
    self.navigationItem.titleLabel.text = self.title;
    //self.images = [NSMutableDictionary new];
}

- (void)continueDraft:(AwfulPrivateMessage *)draft
{
    self.draft = draft;
    //self.thread = thread;
    //self.post = nil;
    self.composerTextView.text = draft.content;
    self.title = [draft.subject stringByCollapsingWhitespace];
    self.navigationItem.titleLabel.text = self.title;
    //self.images = [NSMutableDictionary new];
}


- (void)hitCancel
{
    if (self.imageUploadCancelToken) return;
    [self.composerTextView resignFirstResponder];
    self.composerTextView.userInteractionEnabled = NO;
    
    AwfulAlertView *alert = [AwfulAlertView new];
    alert.title = @"Save draft?";
    alert.message = @"This is a piece of shit and you should "
    "spare yourself embarrassment and just delete it.";
    [alert addCancelButtonWithTitle:@"Delete" block:^{ [self cancel];  }];
    [alert addButtonWithTitle:@"Save" block:^{ [self cancel]; }];
    [alert show];
    
}

-(void) didReplaceImagePlaceholders:(NSString *)newMessageString {
    self.draft.content = newMessageString;
    [super didReplaceImagePlaceholders:newMessageString];
}


- (void)send
{
    
    id op = [[AwfulHTTPClient client] sendPrivateMessage:self.draft
                                                 andThen:^(NSError *error, AwfulPrivateMessage *message)
             {
                 if (error) {
                     [SVProgressHUD dismiss];
                     [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
                     return;
                 }
                 [SVProgressHUD showSuccessWithStatus:@"Sent"];
             }];
    self.networkOperation = op;
     
}

-(AwfulAlertView*) confirmationAlert
{
    AwfulAlertView *alert = [AwfulAlertView new];
    alert.title = @"Send Message?";
    alert.message = @"No one cares what you think and you should "
    "probably kill yourself. Send message anyway?";
    [alert addCancelButtonWithTitle:@"Nope"
                              block:^{ [self.composerTextView becomeFirstResponder]; }];
    [alert addButtonWithTitle:self.sendButton.title block:^{  }];
    return alert;
}
@end
