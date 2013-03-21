//
//  AwfulTableViewController.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
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
// anObject may be nil, in which case it's up to the subclass to find the relevant object.
- (void)configureCell:(UITableViewCell*)cell
           withObject:(id)anObject
          atIndexPath:(NSIndexPath *)indexPath;

@end
