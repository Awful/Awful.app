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
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if([[segue identifier] isEqualToString:@"AwfulPage"]) {
        [self.networkOperation cancel];
        
        NSIndexPath *selected = [self.tableView indexPathForSelectedRow];
        AwfulThread *thread = [self getThreadAtIndexPath:selected];
        AwfulPage *page = (AwfulPage *)segue.destinationViewController;
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

/*
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}*/


- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

/*
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}
*/

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

// Customize the appearance of table view cells.
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
