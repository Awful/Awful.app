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

@interface AwfulThreadList : AwfulTableViewController <AwfulHistoryRecorder> {
    NSMutableArray *awfulThreads;
    AwfulForum *forum;
    int swipedRow;
    
    UIButton *firstPageButton;
    UIButton *lastPageButton;
    
    UIButton *nextPageButton;
    UIButton *prevPageButton;
}

@property (nonatomic, retain) AwfulForum *forum;
@property (nonatomic, retain) NSMutableArray *awfulThreads;

-(id)initWithString : (NSString *)str atPageNum : (int)page_num;
-(id)initWithAwfulForum : (AwfulForum *)in_forum atPageNum : (int)page_num;
-(id)initWithAwfulForum : (AwfulForum *)in_forum;

-(void)configureButtons;
-(AwfulThread *)getThreadAtIndexPath : (NSIndexPath *)path;
-(UIColor *)getBackgroundColorForThread : (AwfulThread *)thread;

-(void)acceptThreads : (NSMutableArray *)in_threads;
-(void)swipedRow:(UISwipeGestureRecognizer *)gestureRecognizer;
-(void)firstPage;
-(void)lastPage;
-(void)loadList;

-(void)nextPage;
-(void)prevPage;

-(NSString *)getSaveID;
-(NSString *)getURLSuffix;

-(void)choseForumOption : (int)option;
-(int)getTypeAtIndexPath : (NSIndexPath *)path;

-(UITableViewCell *)makeThreadListCell;

-(void)slideToBottom;
-(void)slideToTop;

@end
