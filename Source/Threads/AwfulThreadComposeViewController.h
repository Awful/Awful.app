//  AwfulThreadComposeViewController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulComposeViewController.h"
#import "AwfulModels.h"
@protocol AwfulThreadComposeViewControllerDelegate;

@interface AwfulThreadComposeViewController : AwfulComposeViewController

// Designated initializer.
- (id)initWithForum:(AwfulForum *)forum;

@property (readonly, nonatomic) AwfulForum *forum;

@property (weak, nonatomic) id <AwfulThreadComposeViewControllerDelegate> delegate;

@end


@protocol AwfulThreadComposeViewControllerDelegate <NSObject>

// Sent after successfully posting the thread.
- (void)threadComposeController:(AwfulThreadComposeViewController *)controller
            didPostThreadWithID:(NSString *)threadID;

// Sent if the user cancels writing the OP.
- (void)threadComposeControllerDidCancel:(AwfulThreadComposeViewController *)controller;

@end
