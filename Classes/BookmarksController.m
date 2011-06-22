//
//  BookmarksController.m
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "BookmarksController.h"
#import "AwfulAppDelegate.h"
#import "AwfulNavController.h"
#import "AwfulThread.h"
#import "AwfulThreadList.h"
#import "TFHpple.h"
#import "AwfulPage.h"
#import "AwfulUtil.h"
#import "AwfulParse.h"
#import "Stylin.h"
#import "ASIFormDataRequest.h"
#import "AwfulConfig.h"
#import "AwfulPageCount.h"

@implementation BookmarksController


#pragma mark -
#pragma mark Initialization

-(id)init
{
    self = [super initWithString:@"Bookmarks" atPageNum:1];
    
    UIView *custom_title = [Stylin newCustomNavbarTitleWithText:@"Bookmarks"];
        
    UITapGestureRecognizer *top_tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(slideToTop)];
    [custom_title addGestureRecognizer:top_tap];
    [top_tap release];
    
    [self.navigationItem setTitleView:custom_title];
    [custom_title release];
    
    NSMutableArray *old_bookmarks = [AwfulUtil newThreadListForForumId:[self getSaveID]];
    [self setAwfulThreads:old_bookmarks];
    [old_bookmarks release];
    
    AwfulForumRefreshRequest *ref_req = [[AwfulForumRefreshRequest alloc] initWithAwfulThreadList:self];
    AwfulNavController *nav = getnav();
    [nav setBookmarksRefreshReq:ref_req];
    [ref_req release];
    
    self.tableView.delegate = self;
    
    refreshed = NO;
    
    refreshTimer = nil;
    [self startTimer];
    
    return self;
}

-(void)dealloc
{
    [refreshTimer release];
    [super dealloc];
}

#pragma mark -
#pragma mark View lifecycle


-(void)viewDidLoad {
    [super viewDidLoad];
    
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(hitDone)];
    self.delegate.navigationItem.rightBarButtonItem = done;
    [done release];

    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    //self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

-(BOOL)shouldReloadOnViewLoad
{
    return NO;
}

-(void)startTimer
{
    if(refreshed || refreshTimer != nil) {
        return;
    }
    
    AwfulNavController *nav = getnav();
    float delay = [AwfulConfig bookmarksDelay];
    refreshTimer = [NSTimer scheduledTimerWithTimeInterval:delay target:nav selector:@selector(callBookmarksRefresh) userInfo:nil repeats:NO];
    [refreshTimer retain];
}

-(void)endTimer
{
    if([refreshTimer isValid]) {
        [refreshTimer invalidate];
        [refreshTimer release];
        refreshTimer = nil;
    }
}

-(void)refresh
{
    [self endTimer];
    self.view.userInteractionEnabled = NO;
    [UIView animateWithDuration:0.25 animations:^{
        self.view.alpha = 0.3;
    }];
    refreshed = YES;
    [super refresh];
}

-(void)prevPage
{
    if(self.pages.currentPage > 1) {
        [self.awfulThreads removeAllObjects];
        [self.tableView reloadData];
        self.pages.currentPage--;
        [self refresh];
    }
}

-(void)nextPage
{
    [self.awfulThreads removeAllObjects];
    [self.tableView reloadData];
    self.pages.currentPage++;
    [self refresh];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self endTimer];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self startTimer];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if(!decelerate) {
        [self startTimer];
    }
}

-(void)hitDone
{
    [self endTimer];
    AwfulNavController *nav = getnav();
    [nav dismissModalViewControllerAnimated:YES];
}

-(NSString *)getSaveID
{
    return @"bookmarks";
}

-(NSString *)getURLSuffix
{
    return [NSString stringWithFormat:@"bookmarkthreads.php?pagenumber=%d", self.pages.currentPage];
}

-(BOOL)isTitleBarInTable
{
    return NO;
}

-(void)swipedRow:(UISwipeGestureRecognizer *)gestureRecognizer
{
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    if(indexPath.row == [self.awfulThreads count]) {
        return NO;
    }
    return YES;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    int total = [self.awfulThreads count];
    
    // bottom page-nav cell
    if(self.pages.currentPage > 1 || ([self.awfulThreads count] > 0)) {
        total++;
    }
    
    return total;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        AwfulThread *t = [[self.awfulThreads objectAtIndex:indexPath.row] retain];
        [self.awfulThreads removeObjectAtIndex:indexPath.row];
        [AwfulUtil saveThreadList:self.awfulThreads forForumId:[self getSaveID]];       
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
        

        ASIFormDataRequest *req = [ASIFormDataRequest requestWithURL:[NSURL URLWithString:@"http://forums.somethingawful.com/bookmarkthreads.php"]];
        req.userInfo = [NSDictionary dictionaryWithObject:@"Removed from bookmarks." forKey:@"completionMsg"];
        
        [req setPostValue:@"1" forKey:@"json"];
        [req setPostValue:@"remove" forKey:@"action"];
        [req setPostValue:t.threadID forKey:@"threadid"];
        
        AwfulNavController *nav = getnav();
        [nav loadRequestAndWait:req];
        
        [t release];

    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}

@end

