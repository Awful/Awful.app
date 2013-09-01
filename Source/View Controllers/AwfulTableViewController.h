//  AwfulTableViewController.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

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
