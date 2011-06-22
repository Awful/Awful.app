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
#import "AwfulTableViewController.h"

@class AwfulPageCount;
@class AwfulThread;

@interface AwfulThreadCell : UITableViewCell {
    UILabel *_threadTitleLabel;
    UILabel *_pagesLabel;
    UIButton *_unreadButton;
    UIImageView *_sticky;
}

@property (nonatomic, retain) IBOutlet UILabel *threadTitleLabel;
@property (nonatomic, retain) IBOutlet UILabel *pagesLabel;
@property (nonatomic, retain) IBOutlet UIButton *unreadButton;
@property (nonatomic, retain) IBOutlet UIImageView *sticky;

-(void)configureForThread : (AwfulThread *)thread;
-(UIColor *)getBackgroundColorForThread : (AwfulThread *)thread;

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

@interface AwfulThreadList : AwfulTableViewController <AwfulHistoryRecorder> {
    NSMutableArray *_awfulThreads;
    AwfulForum *_forum;
    
    AwfulThreadCell *_threadCell;
    AwfulPageNavCell *_pageNavCell;
}

@property (nonatomic, retain) AwfulForum *forum;
@property (nonatomic, retain) NSMutableArray *awfulThreads;
@property (nonatomic, retain) IBOutlet AwfulThreadCell *threadCell;
@property (nonatomic, retain) IBOutlet AwfulPageNavCell *pageNavCell;

-(id)initWithString : (NSString *)str atPageNum : (int)page_num;
-(id)initWithAwfulForum : (AwfulForum *)in_forum atPageNum : (int)page_num;
-(id)initWithAwfulForum : (AwfulForum *)in_forum;

-(AwfulThread *)getThreadAtIndexPath : (NSIndexPath *)path;

-(void)acceptThreads : (NSMutableArray *)in_threads;
-(void)loadList;
-(BOOL)shouldReloadOnViewLoad;

-(void)firstPage;
-(void)lastPage;
-(IBAction)nextPage;
-(IBAction)prevPage;

-(NSString *)getSaveID;
-(NSString *)getURLSuffix;

-(void)choseForumOption : (int)option;
-(AwfulThreadCellType)getTypeAtIndexPath : (NSIndexPath *)path;

@end
