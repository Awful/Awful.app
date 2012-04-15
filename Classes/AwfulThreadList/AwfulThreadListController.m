//
//  AwfulThreadList.m
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThreadListController.h"
#import "AwfulThread.h"
#import "AwfulThread+AwfulMethods.h"
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

@implementation AwfulThreadListController

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
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(contextDidSave:)
                                                 name:NSManagedObjectContextDidSaveNotification
                                               object:[ApplicationDelegate managedObjectContext]];
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

-(void)loadPageNum : (NSUInteger)pageNum
{    
    [self.networkOperation cancel];
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

- (void)contextDidSave:(NSNotification *)note
{
    // TODO this gets called a bunch. Get rid of it in favour of something like
    // NSFetchedResultsController.
    NSArray *threadIDs = [self.awfulThreads valueForKey:@"threadID"];
    NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"AwfulThread"];
    fetch.predicate = [NSPredicate predicateWithFormat:@"threadID IN %@", threadIDs];
    fetch.sortDescriptors = [NSArray arrayWithObjects:
                             [NSSortDescriptor sortDescriptorWithKey:@"stickyIndex" ascending:NO],
                             [NSSortDescriptor sortDescriptorWithKey:@"lastPostDate" ascending:NO],
                             nil];
    NSError *error;
    NSArray *newThreads = [[ApplicationDelegate managedObjectContext] executeFetchRequest:fetch
                                                                                    error:&error];
    if (!newThreads)
        NSLog(@"error reloading threads %@: %@", threadIDs, error);
    [self.awfulThreads removeAllObjects];
    [self acceptThreads:[newThreads mutableCopy]];
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

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:NSManagedObjectContextDidSaveNotification
                                                  object:[ApplicationDelegate managedObjectContext]];
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
        return cell;
    } else if(type == AwfulThreadCellTypeLoadMore) {
        return [tableView dequeueReusableCellWithIdentifier:moreCell];
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
