//
//  AwfulThreadList.h
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulTableViewController.h"

@class AwfulPageCount;
@class AwfulForum;
@class AwfulThread;
@class AwfulSplitViewController;
@class AwfulThreadCell;

@interface AwfulThreadList : AwfulTableViewController

@property (nonatomic, strong) AwfulForum *forum;
@property (nonatomic, strong) NSMutableArray *awfulThreads;
@property (nonatomic, strong) AwfulPageCount *pages;

@property (nonatomic, strong) IBOutlet UIBarButtonItem *prevPageBarButtonItem;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *pageLabelBarButtonItem;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *nextPageBarButtonItem;

-(AwfulThread *)getThreadAtIndexPath : (NSIndexPath *)path;

-(void)acceptThreads : (NSMutableArray *)in_threads;
-(BOOL)shouldReloadOnViewLoad;

-(IBAction)nextPage;
-(IBAction)prevPage;
-(void)updatePagesLabel;
-(void)loadPageNum : (NSUInteger)pageNum;

-(void)newlyVisible;

@end

@interface AwfulThreadListIpad : AwfulThreadList

@end
