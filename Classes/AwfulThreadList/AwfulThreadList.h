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

@interface AwfulThreadCell : UITableViewCell {
    UILabel *_threadTitleLabel;
    UILabel *_pagesLabel;
    UIButton *_unreadButton;
    UIImageView *_sticky;
    AwfulThread *_thread;
}

@property (nonatomic, strong) IBOutlet UILabel *threadTitleLabel;
@property (nonatomic, strong) IBOutlet UILabel *pagesLabel;
@property (nonatomic, strong) IBOutlet UIButton *unreadButton;
@property (nonatomic, strong) IBOutlet UIImageView *sticky;
@property (nonatomic, strong) AwfulThread *thread;

-(void)configureForThread : (AwfulThread *)thread;
-(UIColor *)getBackgroundColorForThread : (AwfulThread *)thread;
-(void)openThreadlistOptions;

@end

@interface AwfulPageNavCell : UITableViewCell {
    UIButton *_nextButton;
    UIButton *_prevButton;
    UILabel *_pageLabel;
}

@property (nonatomic, strong) IBOutlet UIButton *nextButton;
@property (nonatomic, strong) IBOutlet UIButton *prevButton;
@property (nonatomic, strong) IBOutlet UILabel *pageLabel;

-(void)configureForPageCount : (AwfulPageCount *)pages thread_count : (int)count;

@end

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
