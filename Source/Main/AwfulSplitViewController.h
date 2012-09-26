//
//  AwfulSplitViewController.h
//  Awful
//
//  Created by Sean Berry on 10/18/11.
//  Copyright (c) 2011 Regular Berry Software LLC. All rights reserved.
//

@protocol SubstitutableDetailViewController <NSObject>

- (void)showRootPopoverButtonItem:(UIBarButtonItem *)barButtonItem;
- (void)invalidateRootPopoverButtonItem:(UIBarButtonItem *)barButtonItem;

@end


@interface AwfulSplitViewController : UISplitViewController <UISplitViewControllerDelegate>

@property (nonatomic, strong) UIPopoverController *masterPopoverController;
@property (nonatomic, strong) UIBarButtonItem *rootPopoverButtonItem;

@end
