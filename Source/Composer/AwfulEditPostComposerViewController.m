//
//  AwfulEditPostComposerViewController.m
//  Awful
//
//  Created by me on 1/8/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulEditPostComposerViewController.h"

@implementation AwfulEditPostComposerViewController

- (id)initWithPost:(AwfulPost *)post bbCode:(NSString *)bbCode
{
    self = [super init];
    self.post = post;
    self.thread = nil;
    self.composerTextView.text = bbCode;
    self.title = [post.thread.title stringByCollapsingWhitespace];
    self.navigationItem.titleLabel.text = self.title;
    self.sendButton.title = @"Save";
    self.images = [NSMutableDictionary new];
    return self;
}


- (void)send
{
    id op = [[AwfulHTTPClient client] editPostWithID:self.post.postID
                                                text:self.reply
                                             andThen:^(NSError *error)
             {
                 if (error) {
                     [SVProgressHUD dismiss];
                     [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
                     return;
                 }
                 [SVProgressHUD showSuccessWithStatus:@"Edited"];
                 [self.delegate composerViewController:self didSend:self.post];
             }];
    self.networkOperation = op;
}

-(AwfulAlertView*) confirmationAlert
{
    AwfulAlertView *alert = [AwfulAlertView new];
    alert.title = @"Save Edits?";
    alert.message = @"Are you sure you fixed all the mistakes in "
    "your post? I find that very hard to believe.";
    [alert addCancelButtonWithTitle:@"Nope"
                              block:^{ [self.composerTextView becomeFirstResponder]; }];
    [alert addButtonWithTitle:self.sendButton.title block:^{ }];
    return alert;
}
@end
