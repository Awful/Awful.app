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

@property (nonatomic, retain) IBOutlet UILabel *threadTitleLabel;
@property (nonatomic, retain) IBOutlet UILabel *pagesLabel;
@property (nonatomic, retain) IBOutlet UIButton *unreadButton;
@property (nonatomic, retain) IBOutlet UIImageView *sticky;
@property (nonatomic, retain) AwfulThread *thread;

-(void)configureForThread : (AwfulThread *)thread;
-(UIColor *)getBackgroundColorForThread : (AwfulThread *)thread;
-(void)openThreadlistOptions;

@end

@interface AwfulPageNavCell : UITableViewCell {
    UIButton *_nextButton;
    UIButton *_prevButton;
    UILabel *_pageLabel;
}

@property (nonatomic, retain) IBOutlet UIButton *nextButton;
@property (nonatomic, retain) IBOutlet UIButton *prevButton;
@property (nonatomic, retain) IBOutlet UILabel *pageLabel;

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
    AwfulNavigator *_delegate;
    
    AwfulThreadCell *_threadCell;
    AwfulPageNavCell *_pageNavCell;
    
    UILabel *_pagesLabel;
    UILabel *_forumLabel;
}

@property (nonatomic, retain) AwfulForum *forum;
@property (nonatomic, retain) NSMutableArray *awfulThreads;
@property (nonatomic, retain) IBOutlet AwfulThreadCell *threadCell;
@property (nonatomic, retain) IBOutlet AwfulPageNavCell *pageNavCell;
@property (nonatomic, retain) AwfulPageCount *pages;
@property (nonatomic, assign) AwfulNavigator *delegate;
@property (nonatomic, retain) UILabel *pagesLabel;
@property (nonatomic, retain) UILabel *forumLabel;

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

@property (nonatomic, retain) NSTimer *refreshTimer;
@property (nonatomic, assign) BOOL refreshed;

-(void)startTimer;
-(void)endTimer;

-(void)swapToRefreshButton;
-(void)swapToStopButton;

@end
