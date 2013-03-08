//
//  AwfulTableViewController.h
//  Awful
//
//  Created by Sean Berry on 2/29/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulThemingViewController.h"

@interface AwfulTableViewController : UITableViewController <AwfulThemingViewController>

@property (nonatomic) NSOperation *networkOperation;

@property (nonatomic) BOOL refreshing;

- (void)refresh;

- (void)nextPage;

- (void)stop;

// Subclasses can implement to override the default behavior of YES.
- (BOOL)canPullToRefresh;

// Subclasses can implement to override the default behavior of NO.
- (BOOL)canPullForNextPage;

// Subclasses can implement to override the default behavior of NO.
- (BOOL)refreshOnAppear;

// Subclasses must implement this method and must not call super.
- (void)configureCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath *)indexPath;

@end
