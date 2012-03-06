//
//  AwfulThreadList.m
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThreadList.h"
#import "AwfulThread.h"
#import "AwfulAppDelegate.h"
#import "AwfulPage.h"
#import "AwfulPageCount.h"
#import "AwfulConfig.h"
#import "AwfulUtil.h"
#import "AwfulSplitViewController.h"
#import "AwfulThreadCell.h"
#import "AwfulNetworkEngine.h"
#import "AwfulForum.h"
#import <QuartzCore/QuartzCore.h>

#define THREAD_HEIGHT 72

@implementation AwfulThreadList

#pragma mark -
#pragma mark Initialization

@synthesize forum = _forum;
@synthesize awfulThreads = _awfulThreads;
@synthesize pages = _pages;
@synthesize pageLabelBarButtonItem = _pageLabelBarButtonItem;
@synthesize nextPageBarButtonItem = _nextPageBarButtonItem;
@synthesize prevPageBarButtonItem = _prevPageBarButtonItem;

-(void)awakeFromNib
{
    self.pages = [[AwfulPageCount alloc] init];
    self.pages.currentPage = 1;
    self.title = self.forum.name;
    self.awfulThreads = [[NSMutableArray alloc] init];
    [self updatePagesLabel];
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if([[segue identifier] isEqualToString:@"AwfulPage"]) {
        [self.networkOperation cancel];
        
        NSIndexPath *selected = [self.tableView indexPathForSelectedRow];
        AwfulThread *thread = [self getThreadAtIndexPath:selected];
        AwfulPage *page = (AwfulPage *)segue.destinationViewController;
        page.thread = thread;
        page.title = thread.title;
        
        AwfulPageDestinationType destination = AwfulPageDestinationTypeNewpost;
        if(thread.totalUnreadPosts == -1) {
            destination = AwfulPageDestinationTypeFirst;
        } else if(thread.totalUnreadPosts == 0) {
            destination = AwfulPageDestinationTypeLast;
            // if the last page is full, it won't work if you go for &goto=newpost, that's why I'm setting this to last page
        }
        
        page.destinationType = destination;
        [page refresh];
    }
}

-(void)setForum:(AwfulForum *)forum
{
    if(_forum != forum) {
        _forum = forum;
        self.title = _forum.name;
    }
}

-(void)choseForumOption : (int)option
{
    if(option == 0 && self.pages.currentPage > 1) {
        [self prevPage];
    } else if(option == 0 && self.pages.currentPage == 1) {
        [self nextPage];
    } else if(option == 1 && self.pages.currentPage > 1) {
        [self nextPage];
    }
}

-(void)refresh
{   
    [super refresh];
    [self loadPageNum:self.pages.currentPage];
}

-(void)loadPageNum : (NSUInteger)pageNum
{    
    [self.networkOperation cancel];
    self.networkOperation = [ApplicationDelegate.awfulNetworkEngine threadListForForum:self.forum pageNum:pageNum onCompletion:^(NSMutableArray *threads) {
        [self acceptThreads:threads];
        self.pages.currentPage = pageNum;
        [self updatePagesLabel];
    } onError:^(NSError *error) {
        [self swapToRefreshButton];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failed" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        [alert show];
    }];
}

-(IBAction)prevPage
{
    if(self.pages.currentPage > 1) {
        [self loadPageNum:self.pages.currentPage-1];
    }
}

-(IBAction)nextPage
{
    [self loadPageNum:self.pages.currentPage+1];
    // is there a limit to the number of pages in a forum? whatever, like some asshole is going to go that far back
}

-(void)newlyVisible
{
    //For subclassing
}

-(void)acceptThreads : (NSMutableArray *)in_threads
{
    [self swapToRefreshButton];
    [UIView animateWithDuration:0.2 animations:^(void){
        self.view.alpha = 1.0;
    }];
    
    self.awfulThreads = in_threads;
    
    float offwhite = 241.0/255;
    self.tableView.backgroundColor = [UIColor colorWithRed:offwhite green:offwhite blue:offwhite alpha:1.0];
    [self.tableView reloadData];
    self.view.userInteractionEnabled = YES;
}

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UILabel *lab = (UILabel *)self.navigationItem.titleView;
    lab.numberOfLines = 2;
    lab.text = self.forum.name;
    self.title = @"GBS";
    
    self.tableView.separatorColor = [UIColor colorWithRed:0.75 green:0.75 blue:0.75 alpha:1.0];
    [self.navigationController setToolbarHidden:NO];
    
    [self swapToRefreshButton];
    
    if([self.awfulThreads count] == 0) {
        [self refresh];
    }
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

-(BOOL)shouldReloadOnViewLoad
{
    return NO;
}

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return (toInterfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self.tableView reloadData];
}

/*
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}*/

/*
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}*/


- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.networkOperation cancel];
}

/*
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}
*/

-(void)updatePagesLabel
{
    self.pageLabelBarButtonItem.title = [NSString stringWithFormat:@"Page %d", self.pages.currentPage];
    if(self.pages.currentPage <= 1) {
        self.prevPageBarButtonItem.enabled = NO;
    } else {
        self.prevPageBarButtonItem.enabled = YES;
    }
}

-(AwfulThread *)getThreadAtIndexPath : (NSIndexPath *)path
{    
    AwfulThread *thread = nil;
    
    if(path.row < [self.awfulThreads count]) {
        thread = [self.awfulThreads objectAtIndex:path.row];
    } else {
        NSLog(@"thread out of bounds");
    }
    
    return thread;
}

#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [self.awfulThreads count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [AwfulUtil getThreadCellHeight];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *threadCell = @"ThreadCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:threadCell];
    
    AwfulThread *thread = [self getThreadAtIndexPath:indexPath];
    AwfulThreadCell *thread_cell = (AwfulThreadCell *)cell;
    [thread_cell configureForThread:thread];
    
    return cell;
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return NO;
}

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:YES];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/


/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/


/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}

#pragma mark -
#pragma AwfulHistoryRecorder

-(id)newRecordedHistory
{
    AwfulHistory *hist = [[AwfulHistory alloc] init];
    hist.pageNum = self.pages.currentPage;
    hist.modelObj = self.forum;
    hist.historyType = AwfulHistoryTypeThreadlist;
    return hist;
}

-(id)initWithAwfulHistory : (AwfulHistory *)history
{
    return nil;//return [self initWithAwfulForum:history.modelObj atPageNum:history.pageNum];
}

#pragma mark -
#pragma mark Navigator Content

-(UIView *)getView
{
    return self.view;
}

-(AwfulActions *)getActions
{
    return nil;
}

-(void)scrollToBottom
{
    
}

@end


@implementation AwfulThreadListIpad
@synthesize refreshTimer = _refreshTimer;
@synthesize refreshed = _refreshed;

//Copied to AwfulBookmarksControllerIpad
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    AwfulThread *thread = [self getThreadAtIndexPath:indexPath];
    
    if(thread.threadID != nil) {
        int start = AwfulPageDestinationTypeNewpost;
        if(thread.totalUnreadPosts == -1) {
            start = AwfulPageDestinationTypeFirst;
        } else if(thread.totalUnreadPosts == 0) {
            start = AwfulPageDestinationTypeLast;
            // if the last page is full, it won't work if you go for &goto=newpost
            // therefore I'm setting it to last page here
        }
        
        AwfulPageIpad *thread_detail = [[AwfulPageIpad alloc] initWithAwfulThread:thread startAt:start];
        loadContentVC(thread_detail);
    }
}


-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    return YES;
}
    
-(void)viewDidLoad
{
    [super viewDidLoad];
    [self swapToStopButton];
}

-(void)refresh
{
    [self endTimer];
    [super refresh];
    [self swapToStopButton];
}

-(void)stop
{
    [self endTimer];
    [super stop];
}

-(void) newlyVisible
{
    [self endTimer];
    self.refreshed = NO;
    [self startTimer];
}

-(void)startTimer
{
    if(self.refreshed || self.refreshTimer != nil) {
        return;
    }
    
    AwfulNavigator *nav = getNavigator();
    float delay = [AwfulConfig forumsDelay];
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:delay target:nav selector:@selector(callForumsRefresh) userInfo:nil repeats:NO];
}

-(void)endTimer
{
    if([self.refreshTimer isValid]) {
        [self.refreshTimer invalidate];
    }    
    self.refreshTimer = nil;
}

-(void)acceptThreads:(NSMutableArray *)in_threads
{
    [super acceptThreads:in_threads];
    [self swapToRefreshButton];
}

@end
