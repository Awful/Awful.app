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
#import "AwfulPage.h"
#import "AwfulSettings.h"
#import "AwfulThread.h"
#import "AwfulThread+AwfulMethods.h"
#import "AwfulThreadCell.h"
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
@synthesize currentPage = _currentPage;
@synthesize numberOfPages = _numberOfPages;
@synthesize pageLabelBarButtonItem = _pageLabelBarButtonItem;
@synthesize nextPageBarButtonItem = _nextPageBarButtonItem;
@synthesize prevPageBarButtonItem = _prevPageBarButtonItem;
@synthesize heldThread = _heldThread;
@synthesize isLoading = _isLoading;

-(void)awakeFromNib
{
    self.currentPage = 1;
    self.title = self.forum.name;
    self.awfulThreads = [[NSMutableArray alloc] init];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(awfulThreadUpdated:)
                                                 name:AwfulThreadDidUpdateNotification
                                               object:nil];
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if([[segue identifier] isEqualToString:@"AwfulPage"]) {
        [self.networkOperation cancel];
        
        NSIndexPath *selected = [self.tableView indexPathForSelectedRow];
        
        AwfulPage *page = nil;
        if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
            page = (AwfulPage *)segue.destinationViewController;
        } else if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            UINavigationController *nav = (UINavigationController *)segue.destinationViewController;
            page = (AwfulPage *)nav.topViewController;
        }
        
        page.thread = [self getThreadAtIndexPath:selected];
        [page refresh];
        
        if ([self splitViewController])
        {
            [self.splitViewController prepareForSegue:segue sender:sender];
        }
        
        [[NSNotificationCenter defaultCenter] postNotificationName:AwfulPageWillLoadNotification
                                                            object:[self getThreadAtIndexPath:selected]];

        
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
    self.networkOperation = [[AwfulHTTPClient sharedClient] threadListForForum:self.forum pageNum:pageNum onCompletion:^(NSMutableArray *threads) {
        self.currentPage = pageNum;
        if(pageNum == 1) {
            [self.awfulThreads removeAllObjects];
        }
        [self acceptThreads:threads];
        [self finishedRefreshing];
    } onError:^(NSError *error) {
        [self finishedRefreshing];
        [ApplicationDelegate requestFailed:error];
    }];
}


-(void) loadNextControlChanged:(AwfulRefreshControl*)refreshControl {
    [self loadPageNum:self.currentPage+1];
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
                                                    name:AwfulThreadDidUpdateNotification
                                                  object:nil];
}

-(BOOL)shouldReloadOnViewLoad
{
    //check date on last thread we've got, if older than 10? min reload
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
    if (buttonIndex == AwfulThreadListActionsTypeFirstPage) {
        AwfulPage *page = [self.storyboard instantiateViewControllerWithIdentifier:@"AwfulPage"];
        page.thread = self.heldThread;
        page.destinationType = AwfulPageDestinationTypeFirst;
        [self displayPage:page];
        [page loadPageNum:1];
        
    } else if(buttonIndex == AwfulThreadListActionsTypeLastPage) {
        AwfulPage *page = [self.storyboard instantiateViewControllerWithIdentifier:@"AwfulPage"];
        page.thread = self.heldThread;
        page.destinationType = AwfulPageDestinationTypeLast;
        [self displayPage:page];
        [page loadPageNum:0];
        
    } else if(buttonIndex == AwfulThreadListActionsTypeUnread) {
        [self markThreadUnseen:self.heldThread];

    }
}

-(void) markThreadUnseen:(AwfulThread*)thread {
    [[AwfulHTTPClient sharedClient] markThreadUnseen:thread onCompletion:^(void) {
        thread.totalUnreadPosts = [NSNumber numberWithInt:-1];
        [ApplicationDelegate saveContext];
        
    } onError:^(NSError *error) {
        [ApplicationDelegate requestFailed:error];
    }];
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

#pragma mark - Table view data source and delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.awfulThreads count];
    /*
    // bottom page-nav cell
    if([self moreThreads]) {
        total++;
    }
    
    return total;
     */
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 76;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *threadCell = @"ThreadCell";
    
    AwfulThreadCell *cell = [tableView dequeueReusableCellWithIdentifier:threadCell];
    AwfulThread *thread = [self getThreadAtIndexPath:indexPath];
    [cell configureForThread:thread];
    cell.threadListController = self;
    
    return cell;
    
}

#pragma mark table editing to mark cells unread

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    AwfulThread *thread = [self getThreadAtIndexPath:indexPath];
    //NSLog(@"setting canEdit:%i for %@",thread.totalUnreadPostsValue >= 0, thread.title );
    return (thread.totalUnreadPostsValue >= 0);
}

-(NSString*) tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return @"Mark Unread";
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {

    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        AwfulThread *thread = [self getThreadAtIndexPath:indexPath];
        [self markThreadUnseen:thread];
    }   
  
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
    [self performSegueWithIdentifier:@"AwfulPage" 
                              sender:[self.tableView cellForRowAtIndexPath:indexPath]];

}

@end
