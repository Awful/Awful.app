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

@synthesize threadCount = _threadCount;

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
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    UIBarButtonItem *back = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"bookmarks.png"] style:UIBarButtonItemStyleBordered target:nil action:nil];
    self.navigationItem.backBarButtonItem = back;
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:YES];
    [[self.navigationController navigationBar] setTintColor:[UIColor colorWithRed:0 green:91.0/255 blue:135.0/255 alpha:1.0]];
    
    if([self.awfulThreads count] == 0) {
        [self refresh];
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

-(void)acceptThreads:(NSMutableArray *)in_threads
{
    self.threadCount = [self.awfulThreads count] + [in_threads count]; // this needs to be before the super call
    [super acceptThreads:in_threads];
}

-(void)newlyVisible
{
    //[self endTimer];
    //self.refreshed = NO;
    //[self startTimer];
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
        [self finishedRefreshing];
        
    } onError:^(NSError *error) {
        [self finishedRefreshing];
        [AwfulUtil requestFailed:error];
    }];
}

-(BOOL)moreThreads
{
    if(self.threadCount % 40 == 0 && [self.awfulThreads count] > 0) {
        return YES;
    }
    return NO;
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

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        AwfulThread *thread = [self.awfulThreads objectAtIndex:indexPath.row];
        [self.awfulThreads removeObject:thread];   
        [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
        
        self.networkOperation = [ApplicationDelegate.awfulNetworkEngine removeBookmarkedThread:thread onCompletion:^(void) {
            
        } onError:^(NSError *error) {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            [alert show];
        }];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
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
            if([thread.totalUnreadPosts intValue] == -1) {
                start = AwfulPageDestinationTypeFirst;
            } else if([thread.totalUnreadPosts intValue] == 0) {
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

