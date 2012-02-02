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
@class AwfulPageNavCell;

typedef enum {
    AwfulThreadCellTypeUnknown,
    AwfulThreadCellTypeThread,
    AwfulThreadCellTypePageNav
} AwfulThreadCellType;

@interface AwfulThreadList : UITableViewController <AwfulNavigatorContent, AwfulHistoryRecorder> {
    NSMutableArray *_awfulThreads;
    AwfulForum *_forum;
    AwfulPageCount *_pages;
    
    AwfulThreadCell *_threadCell;
    AwfulPageNavCell *_pageNavCell;
    
    UILabel *_pagesLabel;
    UILabel *_forumLabel;
}

@property (nonatomic, strong) AwfulForum *forum;
@property (nonatomic, strong) NSMutableArray *awfulThreads;
@property (nonatomic, strong) IBOutlet AwfulThreadCell *threadCell;
@property (nonatomic, strong) IBOutlet AwfulPageNavCell *pageNavCell;
@property (nonatomic, strong) AwfulPageCount *pages;
@property (nonatomic, weak) AwfulNavigator *navigator;
@property (nonatomic, strong) UILabel *pagesLabel;
@property (nonatomic, strong) UILabel *forumLabel;

-(id)initWithString : (NSString *)str atPageNum : (int)page_num;
-(id)initWithAwfulForum : (AwfulForum *)in_forum atPageNum : (int)page_num;
-(id)initWithAwfulForum : (AwfulForum *)in_forum;

-(AwfulThread *)getThreadAtIndexPath : (NSIndexPath *)path;

-(void)acceptThreads : (NSMutableArray *)in_threads;
-(void)loadList;
-(BOOL)shouldReloadOnViewLoad;

-(IBAction)nextPage;
-(IBAction)prevPage;

-(NSString *)getSaveID;
-(NSString *)getURLSuffix;

-(void)refresh;
-(void)newlyVisible;

-(void)choseForumOption : (int)option;
-(AwfulThreadCellType)getTypeAtIndexPath : (NSIndexPath *)path;

@end

@interface AwfulThreadListIpad : AwfulThreadList {
    NSTimer *_refreshTimer;
    BOOL _refreshed;
}

@property (nonatomic, strong) NSTimer *refreshTimer;
@property (nonatomic, assign) BOOL refreshed;

-(void)startTimer;
-(void)endTimer;

-(void)swapToRefreshButton;
-(void)swapToStopButton;

@end
