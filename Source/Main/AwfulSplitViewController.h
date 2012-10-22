//
//  AwfulSplitViewController.h
//  Awful
//
//  Created by Sean Berry on 10/18/11.
//  Copyright (c) 2011 Regular Berry Software LLC. All rights reserved.
//

@interface AwfulSplitViewController : UISplitViewController

- (void)ensureLeftBarButtonItemOnDetailView;

@property (strong, nonatomic) UIPopoverController *masterPopoverController;
@property (strong, nonatomic) UIBarButtonItem *rootPopoverButtonItem;

- (void)showMasterView;

@end
