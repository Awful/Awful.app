//
//  AwfulThreadList.m
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThreadListController.h"
#import <QuartzCore/QuartzCore.h>
#import "AwfulAppDelegate.h"
#import "AwfulForum.h"
#import "AwfulNetworkEngine.h"
#import "AwfulPage.h"
#import "AwfulPageCount.h"
#import "AwfulSettings.h"
#import "AwfulThread.h"
#import "AwfulThread+AwfulMethods.h"
#import "AwfulThreadCell.h"
#import "AwfulUtil.h"
#import "AwfulLoginController.h"

#define THREAD_HEIGHT 76

typedef enum {
    AwfulThreadListActionsTypeFirstPage = 0,
    AwfulThreadListActionsTypeLastPage,
    AwfulThreadListActionsTypeUnread
} AwfulThreadListActionsType;

@implementation AwfulThreadListController

#pragma mark -
#pragma mark Initialization

@synthesize forum = _forum;
@synthesize awfulThreads = _awfulThreads;
@synthesize pages = _pages;
@synthesize pageLabelBarButtonItem = _pageLabelBarButtonItem;
@synthesize nextPageBarButtonItem = _nextPageBarButtonItem;
@synthesize prevPageBarButtonItem = _prevPageBarButtonItem;
@synthesize heldThread = _heldThread;
@synthesize isLoading = _isLoading;

-(void)awakeFromNib
{
    self.pages = [[AwfulPageCount alloc] init];
    self.pages.currentPage = 1;
    self.title = self.forum.name;
    self.awfulThreads = [[NSMutableArray alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(awfulThreadUpdated:)
                                                 name:AwfulNotifThreadUpdated
                                               object:nil];
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if([[segue identifier] isEqualToString:@"AwfulPage"]) {
        [self.networkOperation cancel];
        
        NSIndexPath *selected = [self.tableView indexPathForSelectedRow];
        AwfulThread *thread = [self getThreadAtIndexPath:selected];
        
        AwfulPage *page = nil;
        if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
            page = (AwfulPage *)segue.destinationViewController;
        } else if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            UINavigationController *nav = (UINavigationController *)segue.destinationViewController;
            page = (AwfulPage *)nav.topViewController;
        }
        
        page.thread = thread;
        [page refresh];
        
        if ([self splitViewController])
        {
            [self.splitViewController prepareForSegue:segue sender:sender];
        }
    }
}

-(void)setForum:(AwfulForum *)forum
{
    if(_forum != forum) {
        _forum = forum;
        self.title = _forum.name;
    }
}

-(void)refresh
{   
    [super refresh];
    [self loadPageNum:1];
}

-(void)stop
{
    [self.networkOperation cancel];
    [self finishedRefreshing];
}

-(void)finishedRefreshing
{
    [super finishedRefreshing];
    self.isLoading = NO;
}

-(void)loadPageNum : (NSUInteger)pageNum
{    
    [self.networkOperation cancel];
    self.isLoading = YES;
    self.networkOperation = [ApplicationDelegate.awfulNetworkEngine threadListForForum:self.forum pageNum:pageNum onCompletion:^(NSMutableArray *threads) {
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

-(void)awfulThreadUpdated : (NSNotification *)notif
{
    AwfulThread *changedThread = [notif object];
    NSIndexPath *path = nil;
    for(AwfulThread *thread in self.awfulThreads) {
        if(thread == changedThread) {
            path = [NSIndexPath indexPathForRow:[self.awfulThreads indexOfObject:thread] inSection:0];
        }
    }
    if(path != nil) {
        [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:path] withRowAnimation:UITableViewRowAnimationFade];
    }
}

-(void)newlyVisible
{
    //For subclassing
}

-(void)acceptThreads : (NSMutableArray *)in_threads
{
    [UIView animateWithDuration:0.2 animations:^(void){
        self.view.alpha = 1.0;
    }];
    
    [self.awfulThreads addObjectsFromArray:in_threads];
    
    float offwhite = 241.0/255;
    self.tableView.backgroundColor = [UIColor colorWithRed:offwhite green:offwhite blue:offwhite alpha:1.0];
    [self.tableView reloadData];
    self.view.userInteractionEnabled = YES;
}

-(void)loadThreads
{
    NSArray *threads = [AwfulThread threadsForForum:self.forum];
    [self acceptThreads:[NSMutableArray arrayWithArray:threads]];
}

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UILabel *lab = (UILabel *)self.navigationItem.titleView;
    lab.numberOfLines = 2;
    lab.text = self.forum.name;
    
    UIBarButtonItem *back = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"list_icon.png"] style:UIBarButtonItemStyleBordered target:nil action:nil];
    self.navigationItem.backBarButtonItem = back;
    
    self.tableView.separatorColor = [UIColor colorWithRed:0.75 green:0.75 blue:0.75 alpha:1.0];
    
    [self loadThreads];
    if([self.awfulThreads count] == 0 && IsLoggedIn()) {
        [self refresh];
    }
}

- (void)viewDidUnload
{
    [self.networkOperation cancel];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AwfulNotifThreadUpdated
                                                  object:nil];
}

-(BOOL)shouldReloadOnViewLoad
{
    return NO;
}

-(void)showThreadActionsForThread : (AwfulThread *)thread
{
    self.heldThread = thread;
    NSArray *titles = [NSArray arrayWithObjects:@"First Page", @"Last Page", @"Mark as Unread", nil];
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Thread Actions" delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    for(NSString *title in titles) {
        [sheet addButtonWithTitle:title];
    }
    [sheet addButtonWithTitle:@"Cancel"];
    sheet.cancelButtonIndex = [titles count];
    
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [sheet showFromTabBar:self.tabBarController.tabBar];
    } else if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        NSUInteger index = [self.awfulThreads indexOfObject:thread];
        if(index != NSNotFound) {
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:index inSection:0]];
            [sheet showFromRect:cell.frame inView:self.tableView animated:YES];
        }
    }
}

-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if(buttonIndex == AwfulThreadListActionsTypeFirstPage) {
        UIStoryboard *story = [AwfulUtil getStoryboard];
        AwfulPage *page = [story instantiateViewControllerWithIdentifier:@"AwfulPage"];
        page.thread = self.heldThread;
        page.destinationType = AwfulPageDestinationTypeFirst;
        [self displayPage:page];
        [page loadPageNum:1];
        
    } else if(buttonIndex == AwfulThreadListActionsTypeLastPage) {
        
        UIStoryboard *story = [AwfulUtil getStoryboard];
        AwfulPage *page = [story instantiateViewControllerWithIdentifier:@"AwfulPage"];
        page.thread = self.heldThread;
        page.destinationType = AwfulPageDestinationTypeLast;
        [self displayPage:page];
        [page loadPageNum:0];
        
    } else if(buttonIndex == AwfulThreadListActionsTypeUnread) {
        [ApplicationDelegate.awfulNetworkEngine markThreadUnseen:self.heldThread onCompletion:^(void) {
            self.heldThread.totalUnreadPosts = [NSNumber numberWithInt:-1];
            [ApplicationDelegate saveContext];
            
        } onError:^(NSError *error) {
            [AwfulUtil requestFailed:error];
        }];
    }
}

-(void)displayPage : (AwfulPage *)page
{
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [self.navigationController pushViewController:page animated:YES];
    } else if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        NSMutableArray *vcs = [NSMutableArray arrayWithArray:self.splitViewController.viewControllers];
        [vcs removeLastObject];
        
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:page];
        [vcs addObject:nav];
        self.splitViewController.viewControllers = vcs;
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    }
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
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
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    int total = [self.awfulThreads count];
    
    // bottom page-nav cell
    if([self moreThreads]) {
        total++;
    }
    
    return total;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [AwfulUtil getThreadCellHeight];
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
        thread_cell.threadListController = self;
        return cell;
    } else if(type == AwfulThreadCellTypeLoadMore) {
        AwfulLoadingThreadCell *loadingCell = [tableView dequeueReusableCellWithIdentifier:moreCell];
        [loadingCell setActivityViewVisible:self.isLoading];
        return loadingCell;
    }
    
    return nil;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
    if(indexPath.row == [self.awfulThreads count]) {
        [self loadPageNum:self.pages.currentPage+1];
        [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
        [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
    } else {
        [self performSegueWithIdentifier:@"AwfulPage" sender:nil];
    }
}

#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
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

-(BOOL)moreThreads
{
    return [self.awfulThreads count] > 0;
}

@end
