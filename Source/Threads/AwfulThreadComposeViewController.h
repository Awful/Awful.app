//
//  AwfulThreadComposeViewController.h
//  Awful
//
//  Created by Nolan Waite on 2013-05-18.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

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
- (void)threadComposeControllerDidPostThread:(AwfulThreadComposeViewController *)controller;

// Sent if the user cancels writing the OP.
- (void)threadComposeControllerDidCancel:(AwfulThreadComposeViewController *)controller;

@end