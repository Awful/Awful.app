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
#import "AwfulPageCount.h"
#import "AwfulThread.h"
#import "AwfulPage.h"
#import "AwfulNetworkEngine.h"
#import "AwfulTableViewController.h"
#import "AwfulThreadCell.h"

@implementation AwfulBookmarksController

-(void)awakeFromNib
{
    [super awakeFromNib];
        
    self.tableView.delegate = self;
    self.title = @"Bookmarks";
}

#pragma mark -
#pragma mark View lifecycle

-(void)viewDidLoad {
    [super viewDidLoad];
    
    // moving the auto refresh to viewWillAppear, because bookmarks get loaded right away because of the tabbarcontroller, even if the user isn't looking at them
    [self stop];
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:YES];
    
    if([self.awfulThreads count] == 0) {
        [self refresh];
    } else {
        [self startTimer];
    }
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

-(BOOL)shouldReloadOnViewLoad
{
    return NO;
}

-(void)newlyVisible
{
    //[self endTimer];
    //self.refreshed = NO;
    //[self startTimer];
}

-(void)acceptThreads:(NSMutableArray *)in_threads
{
    NSMutableArray *threads = [NSMutableArray arrayWithArray:self.awfulThreads];
    [threads addObjectsFromArray:in_threads];
    [super acceptThreads:threads];
}

-(void)refresh
{
    self.pages.currentPage = 1;
    [super refresh];
}

-(void)loadPageNum : (NSUInteger)pageNum
{   
    [self.networkOperation cancel];
    self.networkOperation = [ApplicationDelegate.awfulNetworkEngine threadListForBookmarksAtPageNum:pageNum onCompletion:^(NSMutableArray *threads) {
        self.pages.currentPage = pageNum;
        if(pageNum == 1) {
            [self.awfulThreads removeAllObjects];
        }
        [self acceptThreads:threads];
        [self swapToRefreshButton];
        
    } onError:^(NSError *error) {
        [self swapToRefreshButton];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
    }];
}

/*
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
}*/

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
    if([self moreBookmarkedThreads]) {
        total++;
    }
    
    return total;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *threadCell = @"ThreadCell";
    static NSString *moreCell = @"LoadMoreCell";
    
    
    AwfulThreadCellType type = [self getTypeAtIndexPath:indexPath];
    if(type == AwfulThreadCellTypeThread) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:threadCell];
        AwfulThread *thread = [self getThreadAtIndexPath:indexPath];
        AwfulThreadCell *thread_cell = (AwfulThreadCell *)cell;
        [thread_cell configureForThread:thread];
        return cell;
    } else if(type == AwfulThreadCellTypeLoadMore) {
        return [tableView dequeueReusableCellWithIdentifier:moreCell];
    }
    
    return nil;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        //AwfulThread *thread = [self.awfulThreads objectAtIndex:indexPath.row];
        [self.awfulThreads removeObjectAtIndex:indexPath.row];
        //[AwfulUtil saveThreadList:self.awfulThreads forForumId:[self getSaveID]];       
        [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
        

        /*ASIFormDataRequest *req = [ASIFormDataRequest requestWithURL:[NSURL URLWithString:@"http://forums.somethingawful.com/bookmarkthreads.php"]];
        req.userInfo = [NSDictionary dictionaryWithObject:@"Removed from bookmarks." forKey:@"completionMsg"];
        
        [req setPostValue:@"1" forKey:@"json"];
        [req setPostValue:@"remove" forKey:@"action"];
        [req setPostValue:thread.threadID forKey:@"threadid"];
        
        loadRequestAndWait(req);*/
        

    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
    if(indexPath.row == [self.awfulThreads count]) {
        [self loadPageNum:self.pages.currentPage+1];
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    } else {
        [self performSegueWithIdentifier:@"AwfulPage" sender:nil];
    }
}

-(AwfulThreadCellType)getTypeAtIndexPath : (NSIndexPath *)indexPath
{
    if(indexPath.row < [self.awfulThreads count]) {
        return AwfulThreadCellTypeThread;
    } else if(indexPath.row == [self.awfulThreads count]) {
        return AwfulThreadCellTypeLoadMore;
    }
    return AwfulThreadCellTypeUnknown;
}

-(BOOL)moreBookmarkedThreads
{
    if([self.awfulThreads count] % 40 == 0 && [self.awfulThreads count] > 0) {
        return YES;
    }
    return NO;
}

@end

@implementation AwfulBookmarksControllerIpad
- (id) init
{
    self = [super init];
    if (self)
    {
        
        self.tabBarItem = [[self tabBarItem] initWithTabBarSystemItem:UITabBarSystemItemBookmarks tag:self.tabBarItem.tag];
    }
    return self;

}
//Copied from AwfulThreadListIpad
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    AwfulThreadCellType type = [self getTypeAtIndexPath:indexPath];
    
    if(type == AwfulThreadCellTypeThread) {
        
        AwfulThread *thread = [self getThreadAtIndexPath:indexPath];
        
        if(thread.threadID != nil) {
            AwfulPageDestinationType start = AwfulPageDestinationTypeNewpost;
            if(thread.totalUnreadPosts == -1) {
                start = AwfulPageDestinationTypeFirst;
            } else if(thread.totalUnreadPosts == 0) {
                start = AwfulPageDestinationTypeLast;
                // if the last page is full, it won't work if you go for &goto=newpost
                // therefore I'm setting it to last page here
            }
            
            //AwfulPageIpad *thread_detail = [[AwfulPageIpad alloc] initWithAwfulThread:thread startAt:start];
            //loadContentVC(thread_detail);
        }
    }
}

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}

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
}

-(void)swapToStopButton
{
    UIBarButtonItem *stop = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop target:self action:@selector(stop)];
    self.navigationItem.rightBarButtonItem = stop;
}

@end

