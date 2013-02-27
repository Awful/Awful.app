//
//  AwfulReplyComposeViewController.h
//  Awful
//
//  Created by Sean Berry on 11/21/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulComposeViewController.h"
#import "AwfulModels.h"

@protocol AwfulReplyComposeViewControllerDelegate;


@interface AwfulReplyComposeViewController : AwfulComposeViewController

@property (weak, nonatomic) id <AwfulReplyComposeViewControllerDelegate> delegate;

- (void)editPost:(AwfulPost *)post text:(NSString *)text;

- (void)replyToThread:(AwfulThread *)thread withInitialContents:(NSString *)contents;

@end


@protocol AwfulReplyComposeViewControllerDelegate <NSObject>

- (void)replyComposeController:(AwfulReplyComposeViewController *)controller
                   didEditPost:(AwfulPost *)post;

- (void)replyComposeController:(AwfulReplyComposeViewController *)controller
              didReplyToThread:(AwfulThread *)thread;

- (void)replyComposeControllerDidCancel:(AwfulReplyComposeViewController *)controller;

@end
