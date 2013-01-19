//
//  AwfulReplyViewController.m
//  Awful
//
//  Created by Sean Berry on 11/21/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulReplyComposerViewController.h"
#import "AwfulModels.h"
#import "AwfulAlertView.h"
#import "AwfulHTTPClient.h"
#import "NSString+CollapseWhitespace.h"
#import "SVProgressHUD.h"
#import "UINavigationItem+TwoLineTitle.h"

@interface AwfulReplyComposerViewController ()
@end

@implementation AwfulReplyComposerViewController



- (void)replyToThread:(AwfulThread *)thread withInitialContents:(NSString *)contents
{
    self.thread = thread;
    self.post = nil;
    self.composerTextView.text = contents;
    self.title = [thread.title stringByCollapsingWhitespace];
    self.navigationItem.titleLabel.text = self.title;
    self.sendButton.title = @"Reply";
    self.images = [NSMutableDictionary new];
}

-(void) didReplaceImagePlaceholders:(NSString *)newMessageString {
    self.reply = newMessageString;
    [super didReplaceImagePlaceholders:newMessageString];
}

- (void)send
{
    id op = [[AwfulHTTPClient client] replyToThreadWithID:self.thread.threadID
                                                     text:self.reply
                                                  andThen:^(NSError *error, NSString *postID)
             {
                 if (error) {
                     [SVProgressHUD dismiss];
                     [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
                     return;
                 }
                 [SVProgressHUD showSuccessWithStatus:@"Replied"];
                 [self.delegate composerViewController:self didSend:self.thread];
             }];
    self.networkOperation = op;
}


-(AwfulAlertView*) confirmationAlert
{
    AwfulAlertView *alert = [AwfulAlertView new];
    alert.title = @"Incoming Forums Superstar";
    alert.message = @"Does my reply offer any significant advice or help "
    "contribute to the conversation in any fashion?";
    [alert addCancelButtonWithTitle:@"Nope"
                                           block:^{ [self.composerTextView becomeFirstResponder]; }];
    [alert addButtonWithTitle:self.sendButton.title block:^{ }];
    return alert;
}

@end
