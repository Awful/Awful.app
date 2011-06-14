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
    
    refreshButton.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    stopButton.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    
    UIView *page_view = [titleBar viewWithTag:PAGE_TAG];
    [page_view removeFromSuperview];
    
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
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(hitDone)];
    self.navigationItem.rightBarButtonItem = done;
    [done release];
    
    UIBarButtonItem *ref = [[UIBarButtonItem alloc] initWithCustomView:refreshButton];
    self.navigationItem.leftBarButtonItem = ref;
    [ref release];

    [super viewDidLoad];

    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    //self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

-(void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    CGRect stop_rect;
    if(UIInterfaceOrientationIsPortrait(toInterfaceOrientation)) {
        stop_rect = CGRectMake(10, 5, 30, 30);
    } else {
        stop_rect = CGRectMake(10, 1, 30, 30);
    }
    stopButton.frame = stop_rect;
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
    if(pages.currentPage > 1) {
        [awfulThreads removeAllObjects];
        [self.tableView reloadData];
        pages.currentPage--;
        [self refresh];
    }
}

-(void)nextPage
{
    [awfulThreads removeAllObjects];
    [self.tableView reloadData];
    pages.currentPage++;
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
    return [NSString stringWithFormat:@"bookmarkthreads.php?pagenumber=%d", pages.currentPage];
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
    if(indexPath.row == [awfulThreads count]) {
        return NO;
    }
    return YES;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    int total = [awfulThreads count];
    
    // bottom page-nav cell
    if(pages.currentPage > 1 || ([awfulThreads count] > 0)) {
        total++;
    }
    
    return total;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        AwfulThread *t = [[awfulThreads objectAtIndex:indexPath.row] retain];
        [awfulThreads removeObjectAtIndex:indexPath.row];
        [AwfulUtil saveThreadList:awfulThreads forForumId:[self getSaveID]];       
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

