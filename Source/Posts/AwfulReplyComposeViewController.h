//
//  AwfulReplyComposeViewController.h
//  Awful
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
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
