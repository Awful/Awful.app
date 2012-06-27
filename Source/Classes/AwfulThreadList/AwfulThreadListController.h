//
//  AwfulThreadList.h
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulFetchedTableViewController.h"

@class AwfulForum;
@class AwfulThread;
@class AwfulSplitViewController;
@class AwfulThreadCell;
@class AwfulPage;

typedef enum {
    AwfulThreadCellTypeUnknown,
    AwfulThreadCellTypeThread,
    AwfulThreadCellTypeLoadMore
} AwfulThreadCellType;

@interface AwfulThreadListController : AwfulFetchedTableViewController <UIActionSheetDelegate>

@property (nonatomic, strong) AwfulForum *forum;
@property (nonatomic, strong) NSMutableArray *awfulThreads;
@property (nonatomic, assign) NSInteger currentPage;
@property (nonatomic, assign) NSInteger numberOfPages;

@property (nonatomic, strong) IBOutlet UIBarButtonItem *prevPageBarButtonItem;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *pageLabelBarButtonItem;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *nextPageBarButtonItem;

@property (nonatomic, strong) AwfulThread *heldThread;
@property BOOL isLoading;

-(AwfulThread *)getThreadAtIndexPath : (NSIndexPath *)path;

-(void)acceptThreads : (NSMutableArray *)in_threads;
-(BOOL)shouldReloadOnViewLoad;
-(void)showThreadActionsForThread : (AwfulThread *)thread;

-(void)displayPage : (AwfulPage *)page;
-(void)loadPageNum : (NSUInteger)pageNum;
-(void)stop;

-(void)awfulThreadUpdated : (NSNotification *)notif;

-(AwfulThreadCellType)getTypeAtIndexPath : (NSIndexPath *)indexPath;
-(BOOL)moreThreads;

-(void)newlyVisible;

@end