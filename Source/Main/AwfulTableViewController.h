//
//  AwfulTableViewController.h
//  Awful
//
//  Created by Sean Berry on 2/29/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AwfulTableViewController : UITableViewController

@property (strong, nonatomic) NSOperation *networkOperation;
@property (assign, nonatomic) BOOL reloading;

- (IBAction)refresh;
- (IBAction)nextPage;

- (void)stop;

- (void)finishedRefreshing;

// Subclasses can implement to override the default behavior of YES.
- (BOOL)canPullToRefresh;

// Subclasses can implement to override the default behavior of NO.
- (BOOL)canPullForNextPage;

// Subclasses must implement this method and must not call super.
- (void)configureCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath *)indexPath;

@end
