//
//  AwfulThreadList.h
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "AwfulForum.h"
#import "AwfulPost.h"
#import "AwfulPage.h"
#import "AwfulHistory.h"
#import "AwfulNavigator.h"

@class AwfulPageCount;
@class AwfulThread;
@class AwfulSplitViewController;
@class AwfulThreadCell;

@interface AwfulThreadList : UITableViewController

@property (nonatomic, strong) AwfulForum *forum;
@property (nonatomic, strong) NSMutableArray *awfulThreads;
@property (nonatomic, strong) AwfulPageCount *pages;
@property (nonatomic, strong) MKNetworkOperation *networkOperation;

@property (nonatomic, strong) IBOutlet UIBarButtonItem *prevPageBarButtonItem;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *pageLabelBarButtonItem;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *nextPageBarButtonItem;

-(AwfulThread *)getThreadAtIndexPath : (NSIndexPath *)path;

-(void)acceptThreads : (NSMutableArray *)in_threads;
-(BOOL)shouldReloadOnViewLoad;

-(void)swapToRefreshButton;
-(void)swapToStopButton;

-(IBAction)nextPage;
-(IBAction)prevPage;
-(void)updatePagesLabel;

-(IBAction)refresh;
-(IBAction)stop;
-(void)loadPageNum : (NSUInteger)pageNum;

-(void)newlyVisible;

-(void)choseForumOption : (int)option;

@end

@interface AwfulThreadListIpad : AwfulThreadList {
    NSTimer *_refreshTimer;
    BOOL _refreshed;
}

@property (nonatomic, strong) NSTimer *refreshTimer;
@property (nonatomic, assign) BOOL refreshed;

-(void)startTimer;
-(void)endTimer;

@end
