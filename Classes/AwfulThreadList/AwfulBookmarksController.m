//
//  BookmarksController.m
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulBookmarksController.h"
#import "AwfulUtil.h"
#import "AwfulConfig.h"
#import "AwfulForumRefreshRequest.h"
#import "AwfulNavigator.h"
#import "AwfulRequestHandler.h"
#import "AwfulPageCount.h"
#import "ASIFormDataRequest.h"

@implementation AwfulBookmarksController


#pragma mark -
#pragma mark Initialization

@synthesize refreshTimer = _refreshTimer;
@synthesize refreshed = _refreshed;

-(id)init
{
    self = [super initWithString:@"Bookmarks" atPageNum:1];
    
    if(self) {
                
        NSMutableArray *old_bookmarks = [AwfulUtil newThreadListForForumId:[self getSaveID]];
        self.awfulThreads = old_bookmarks;
        [old_bookmarks release];
        
        if(![[NSUserDefaults standardUserDefaults] boolForKey:@"killbookmarks"]) {
            self.awfulThreads = [NSMutableArray array];
            [AwfulUtil saveThreadList:self.awfulThreads forForumId:[self getSaveID]];
            [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"killbookmarks"];
        }
        
        self.tableView.delegate = self;
        
        _refreshed = NO;
        
        _refreshTimer = nil;
        [self startTimer];
    }
    
    return self;
}

-(void)dealloc
{
    [_refreshTimer release];
    [super dealloc];
}

#pragma mark -
#pragma mark View lifecycle


-(void)viewDidLoad {
    [super viewDidLoad];
    
    self.forumLabel.text = @"Bookmarks";
    self.navigationItem.titleView = self.forumLabel;
    
    [self swapToRefreshButton];
    
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(hitDone)];
    self.navigationItem.rightBarButtonItem = done;
    [done release];
}

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return (toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

-(BOOL)shouldReloadOnViewLoad
{
    return NO;
}

-(void)startTimer
{
    if(self.refreshed || self.refreshTimer != nil) {
        return;
    }
    
    AwfulNavigator *nav = getNavigator();
    float delay = [AwfulConfig bookmarksDelay];
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:delay target:nav selector:@selector(callBookmarksRefresh) userInfo:nil repeats:NO];
}

-(void)endTimer
{
    if([self.refreshTimer isValid]) {
        [self.refreshTimer invalidate];
        self.refreshTimer = nil;
    }
}

-(void)refresh
{
    [self endTimer];
    self.refreshed = YES;
    [self swapToStopButton];
    [super refresh];
}

-(void)stop
{
    self.refreshed = YES;
    [self endTimer];
    [self swapToRefreshButton];
    [super stop];
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
    AwfulNavigator *nav = getNavigator();
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
        AwfulThread *thread = [[self.awfulThreads objectAtIndex:indexPath.row] retain];
        [self.awfulThreads removeObjectAtIndex:indexPath.row];
        [AwfulUtil saveThreadList:self.awfulThreads forForumId:[self getSaveID]];       
        [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
        

        ASIFormDataRequest *req = [ASIFormDataRequest requestWithURL:[NSURL URLWithString:@"http://forums.somethingawful.com/bookmarkthreads.php"]];
        req.userInfo = [NSDictionary dictionaryWithObject:@"Removed from bookmarks." forKey:@"completionMsg"];
        
        [req setPostValue:@"1" forKey:@"json"];
        [req setPostValue:@"remove" forKey:@"action"];
        [req setPostValue:thread.threadID forKey:@"threadid"];
        
        loadRequestAndWait(req);
        
        [thread release];

    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}

#pragma mark Refresh Button Swapping

-(void)acceptThreads : (NSMutableArray *)in_threads
{
    [super acceptThreads:in_threads];
    [self swapToRefreshButton];
}

-(void)swapToRefreshButton
{
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh)];
    self.navigationItem.leftBarButtonItem = refresh;
    [refresh release];
}

-(void)swapToStopButton
{
    UIBarButtonItem *stop = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(stop)];
    self.navigationItem.leftBarButtonItem = stop;
    [stop release];
}

@end

@implementation AwfulBookmarksControllerIpad

-(void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.titleView = nil;
    self.title = @"Bookmarks";
    [self swapToRefreshButton];
}

-(void)swapToRefreshButton
{
    UIBarButtonItem *refresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh target:self action:@selector(refresh)];
    self.navigationItem.rightBarButtonItem = refresh;
    [refresh release];
}

-(void)swapToStopButton
{
    UIBarButtonItem *stop = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(stop)];
    self.navigationItem.rightBarButtonItem = stop;
    [stop release];
}

@end

