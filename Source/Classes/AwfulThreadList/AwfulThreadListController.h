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
@class AwfulPage;

typedef enum {
    AwfulThreadCellTypeUnknown,
    AwfulThreadCellTypeThread,
    AwfulThreadCellTypeLoadMore
} AwfulThreadCellType;

@interface AwfulThreadListController : AwfulFetchedTableViewController <UIActionSheetDelegate>

@property (nonatomic, strong) AwfulForum *forum;
@property (nonatomic, assign) NSInteger currentPage;
@property (nonatomic, assign) NSInteger numberOfPages;

@property (nonatomic, strong) IBOutlet UIBarButtonItem *prevPageBarButtonItem;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *pageLabelBarButtonItem;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *nextPageBarButtonItem;

@property (nonatomic, strong) UIBarButtonItem *customBackButton;

@property (nonatomic, strong) AwfulThread *heldThread;
@property BOOL isLoading;

- (AwfulThread *)getThreadAtIndexPath:(NSIndexPath *)path;

- (BOOL)shouldReloadOnViewLoad;
- (void)showThreadActionsForThread:(AwfulThread *)thread;

- (void)displayPage:(AwfulPage *)page;
- (void)loadPageNum:(NSUInteger)pageNum;
- (void)stop;

- (void)newlyVisible;

@end
