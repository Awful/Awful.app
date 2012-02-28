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
#import "AwfulUtil.h"
#import "TFHpple.h"
#import "AwfulParse.h"
#import "AwfulConfig.h"
#import "AwfulPageCount.h"
#import "AwfulLoginController.h"
#import "AwfulNavigator.h"
#import "AwfulNavigatorLabels.h"
#import "AwfulUtil.h"
#import "AwfulThreadListActions.h"
#import "AwfulSplitViewController.h"
#import "AwfulThreadCell.h"
#import "AwfulPageNavCell.h"
#import "AwfulNetworkEngine.h"
#import <QuartzCore/QuartzCore.h>

#define THREAD_HEIGHT 72

@implementation AwfulThreadList

#pragma mark -
#pragma mark Initialization

@synthesize forum = _forum;
@synthesize awfulThreads = _awfulThreads;
@synthesize threadCell = _threadCell;
@synthesize pageNavCell = _pageNavCell;
@synthesize pages = _pages;
@synthesize navigator = _navigator;
@synthesize pagesLabel = _pagesLabel;
@synthesize forumLabel = _forumLabel;
@synthesize networkOperation = _networkOperation;

-(id)initWithString : (NSString *)str atPageNum : (int)page_num
{
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        self.awfulThreads = [[NSMutableArray alloc] init];
        self.navigator = nil;
        self.pages = [[AwfulPageCount alloc] init];
        self.pages.currentPage = page_num;
        self.title = str;
        self.networkOperation = nil;
    }
    
    return self;
}

-(id)initWithAwfulForum : (AwfulForum *)in_forum atPageNum : (int)page_num
{
    if((self=[self initWithString:in_forum.name atPageNum:page_num])) {
        self.forum = in_forum;
    }
    return self;
}

-(id)initWithAwfulForum : (AwfulForum *)in_forum
{
    return [self initWithAwfulForum:in_forum atPageNum:1];
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if([[segue identifier] isEqualToString:@"AwfulPage"]) {
        NSIndexPath *selected = [self.tableView indexPathForSelectedRow];
        AwfulThread *thread = [self getThreadAtIndexPath:selected];
        AwfulPage *page = (AwfulPage *)segue.destinationViewController;
        page.thread = thread;
        page.destinationType = AwfulPageDestinationTypeFirst;
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

-(NSString *)getSaveID
{
    return self.forum.forumID;
}

-(NSString *)getURLSuffix
{
    return [NSString stringWithFormat:@"forumdisplay.php?forumid=%@&pagenumber=%d", self.forum.forumID, self.pages.currentPage];
}

-(void)loadList
{
    NSMutableArray *threads = [AwfulUtil newThreadListForForumId:[self getSaveID]];
    self.awfulThreads = threads;
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

-(void)refresh
{   
    [self swapToStopButton];
    [UIView animateWithDuration:0.2 animations:^(void){
        self.view.alpha = 0.5;
    }];
    
    [self.networkOperation cancel];
    self.networkOperation = [ApplicationDelegate.awfulNetworkEngine threadListForForum:self.forum pageNum:self.pages.currentPage onCompletion:^(NSMutableArray *threads) {
        [self acceptThreads:threads];
    } onError:^(NSError *error) {
        
    }];
}

-(void)stop
{
    [self.networkOperation cancel];
    [self swapToRefreshButton];
    self.view.userInteractionEnabled = YES;
    [UIView animateWithDuration:0.2 animations:^(void){
        self.view.alpha = 1.0;
    }];
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
    
    AwfulNavigatorLabels *labels = [[AwfulNavigatorLabels alloc] init];
    self.forumLabel = labels.forumLabel;
    self.pagesLabel = labels.pagesLabel;
    UILabel *lab = (UILabel *)self.navigationItem.titleView;
    lab.numberOfLines = 2;
    lab.text = self.forum.name;
    self.title = @"GBS";
    
    self.tableView.separatorColor = [UIColor colorWithRed:0.75 green:0.75 blue:0.75 alpha:1.0];
    
    [self.navigationController setToolbarHidden:NO];
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithTitle:@"Item" style:UIBarButtonItemStyleBordered target:nil action:nil];
    [self setToolbarItems:[NSArray arrayWithObject:item]];
    
    [self.forumLabel setText:self.forum.name];
    [self.pagesLabel setText:[self.pages description]];
    self.navigator.navigationItem.titleView = self.forumLabel;
    
    UIBarButtonItem *cust = [[UIBarButtonItem alloc] initWithCustomView:self.pagesLabel];
    self.navigator.navigationItem.rightBarButtonItem = cust;
    
    if([self shouldReloadOnViewLoad]) {
        [self refresh];
    }
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    
    self.pagesLabel = nil;
    self.forumLabel = nil;
}

-(BOOL)shouldReloadOnViewLoad
{
    return YES;
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

-(void)setPages:(AwfulPageCount *)pages
{
    if(pages != _pages) {
        _pages = pages;
        [self.pagesLabel setText:[_pages description]];
    }
}

-(AwfulThreadCellType)getTypeAtIndexPath : (NSIndexPath *)path
{    
    if(path.row < [self.awfulThreads count]) {
        return AwfulThreadCellTypeThread;
    }
    
    if(path.row == [self.awfulThreads count]) {
        return AwfulThreadCellTypePageNav;
    }
    
    return AwfulThreadCellTypeUnknown;
}

-(AwfulThread *)getThreadAtIndexPath : (NSIndexPath *)path
{    
    if([self getTypeAtIndexPath:path] != AwfulThreadCellTypeThread) {
        return nil;
    }
    
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
    int total = [self.awfulThreads count];
    
    // bottom page-nav cell
    if([self.awfulThreads count] > 0) {
        //total++;
    }
    
    return total;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    float height = 5;
    
    AwfulThreadCellType type = [self getTypeAtIndexPath:indexPath];
    if(type == AwfulThreadCellTypeThread) {
        height = [AwfulUtil getThreadCellHeight];
    } else if(type == AwfulThreadCellTypePageNav) {
        height = 60;
    }
    
    return height;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *threadCell = @"ThreadCell";
    static NSString *pageNav = @"PageNav";
    
    NSString *ident = nil;
    
    AwfulThreadCellType type = [self getTypeAtIndexPath:indexPath];
    if(type == AwfulThreadCellTypeThread) {
        ident = threadCell;
    } else if(type == AwfulThreadCellTypePageNav) {
        ident = pageNav;
    }
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ident];
    
    /*if (cell == nil) {
        [[NSBundle mainBundle] loadNibNamed:@"AwfulThreadListCells" owner:self options:nil];
        
        if(ident == pageNav) {
            cell = self.pageNavCell;
        } else {
            cell = self.threadCell;
        }
        self.threadCell = nil;
        self.pageNavCell = nil;
    }*/
    
    // Configure the cell...
    if(type == AwfulThreadCellTypeThread) {
        AwfulThread *thread = [self getThreadAtIndexPath:indexPath];
        AwfulThreadCell *thread_cell = (AwfulThreadCell *)cell;
        [thread_cell configureForThread:thread];
    } else if(type == AwfulThreadCellTypePageNav) {
        AwfulPageNavCell *nav_cell = (AwfulPageNavCell *)cell;
        [nav_cell configureForPageCount:self.pages thread_count:[self.awfulThreads count]];
    }
    
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
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
     
    AwfulThreadCellType type = [self getTypeAtIndexPath:indexPath];
    
    if(type == AwfulThreadCellTypeThread) {
        
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
            
            AwfulPage *thread_detail = [AwfulPage pageWithAwfulThread:thread startAt:start];
            loadContentVC(thread_detail);
        }
    }
}

-(IBAction)prevPage
{
    if(self.pages.currentPage > 1) {
        AwfulThreadList *prev_list = [[[self class] alloc] initWithAwfulForum:self.forum atPageNum:self.pages.currentPage-1];
        loadContentVC(prev_list);
    }
}

-(IBAction)nextPage
{
    AwfulThreadList *next_list = [[[self class] alloc] initWithAwfulForum:self.forum atPageNum:self.pages.currentPage+1];
    loadContentVC(next_list);
}

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
    return [self initWithAwfulForum:history.modelObj atPageNum:history.pageNum];
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
    
    AwfulThreadCellType type = [self getTypeAtIndexPath:indexPath];
    
    if(type == AwfulThreadCellTypeThread) {
        
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
