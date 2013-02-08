//
//  AwfulReplyViewController.h
//  Awful
//
//  Created by Sean Berry on 11/21/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulModels.h"
#import "AwfulEmoticonKeyboardController.h"

@protocol AwfulReplyViewControllerDelegate;


@interface AwfulReplyViewController : UIViewController <AwfulEmoticonPickerDelegate>

@property (weak, nonatomic) id <AwfulReplyViewControllerDelegate> delegate;

- (void)editPost:(AwfulPost *)post text:(NSString *)text;

- (void)replyToThread:(AwfulThread *)thread withInitialContents:(NSString *)contents;

@end


@protocol AwfulReplyViewControllerDelegate <NSObject>

- (void)replyViewController:(AwfulReplyViewController *)replyViewController
                didEditPost:(AwfulPost *)post;

- (void)replyViewController:(AwfulReplyViewController *)replyViewController
           didReplyToThread:(AwfulThread *)thread;

- (void)replyViewControllerDidCancel:(AwfulReplyViewController *)replyViewController;

@end
