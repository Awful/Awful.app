//
//  AwfulTableViewController.h
//  Awful
//
//  Created by Sean Berry on 2/29/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class AwfulRefreshControl;

@interface AwfulTableViewController : UITableViewController {
    @protected
    AwfulRefreshControl* _awfulRefreshControl;
}

@property (nonatomic, strong) NSOperation *networkOperation;
@property (nonatomic, strong) AwfulRefreshControl *awfulRefreshControl;
@property (nonatomic, assign) BOOL reloading;

-(IBAction)refresh;
-(void)stop;
-(void)finishedRefreshing;

// Subclasses can implement to override the default behaviour of YES.
- (BOOL)canPullToRefresh;

- (void)configureCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath *)indexPath;
@end
