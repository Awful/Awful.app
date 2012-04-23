//
//  AwfulTableViewController.h
//  Awful
//
//  Created by Sean Berry on 2/29/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "EGORefreshTableHeaderView.h"

@interface AwfulTableViewController : UITableViewController <EGORefreshTableHeaderDelegate>

@property (nonatomic, strong) MKNetworkOperation *networkOperation;
@property (nonatomic, strong) EGORefreshTableHeaderView *refreshHeaderView;
@property (nonatomic, assign) BOOL reloading;

-(IBAction)refresh;
-(void)finishedRefreshing;

// Subclasses can implement to override the default behaviour of YES.
- (BOOL)canPullToRefresh;

@end
