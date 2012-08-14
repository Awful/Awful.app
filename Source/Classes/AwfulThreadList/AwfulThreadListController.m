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
#import "AwfulCustomForums.h"
#import "AwfulNewPostComposeController.h"
#import "AwfulRefreshControl.h"

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
@synthesize currentPage = _currentPage;
@synthesize numberOfPages = _numberOfPages;
@synthesize pageLabelBarButtonItem = _pageLabelBarButtonItem;
@synthesize nextPageBarButtonItem = _nextPageBarButtonItem;
@synthesize prevPageBarButtonItem = _prevPageBarButtonItem;
@synthesize heldThread = _heldThread;
@synthesize isLoading = _isLoading;
@synthesize customBackButton = _customBackButton;

-(void)awakeFromNib
{
    self.currentPage = 1;
    self.title = self.forum.name;
    /*
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(awfulThreadUpdated:)
                                                 name:AwfulThreadDidUpdateNotification
                                               object:nil];
    
    */
    [self setEntityName:@"AwfulThread"
              predicate:[NSPredicate predicateWithFormat:@"forum = %@", self.forum]
                   sort:[NSArray arrayWithObjects:
                         [NSSortDescriptor sortDescriptorWithKey:@"stickyIndex" ascending:NO], 
                         [NSSortDescriptor sortDescriptorWithKey:@"lastPostDate" ascending:NO],
                         nil
                         ]
             sectionKey:nil
     ];
    

}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    //if([[segue identifier] isEqualToString:@"AwfulPage"]) {
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

        
    //}
}

-(void)setForum:(AwfulForum *)forum
{
    if(_forum != forum) {
        _forum = forum;
        self.title = _forum.name;
        
        [self setEntityName:@"AwfulThread"
                  predicate:[NSPredicate predicateWithFormat:@"forum = %@", self.forum]
                       sort:[NSArray arrayWithObjects:
                             [NSSortDescriptor sortDescriptorWithKey:@"stickyIndex" ascending:YES], 
                             [NSSortDescriptor sortDescriptorWithKey:@"lastPostDate" ascending:NO],
                             nil
                             ]
                 sectionKey:nil
         ];
    }
}

-(void)refresh
{   
    [super refresh];
    self.awfulRefreshControl.state = AwfulRefreshControlStateLoading;
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
            //[self.awfulThreads removeAllObjects];
        }
        //[self acceptThreads:threads];
        [self finishedRefreshing];
    } onError:^(NSError *error) {
        [self finishedRefreshing];
        [ApplicationDelegate requestFailed:error];
    }];
}


-(void) loadNextControlChanged:(AwfulRefreshControl*)refreshControl {
    [self loadPageNum:self.currentPage+1];
}


-(void) didTapCompose:(UIBarButtonItem*)button {
    UINavigationController *test = [[UINavigationController alloc] initWithRootViewController:[AwfulNewPostComposeController new]];
    test.modalPresentationStyle = UIModalPresentationFormSheet;
    [self.splitViewController presentModalViewController:test animated:YES];
}

#pragma mark -
#pragma mark View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UILabel *lab = (UILabel *)self.navigationItem.titleView;
    lab.numberOfLines = 2;
    lab.text = self.forum.name;
    
    self.tableView.separatorColor = [UIColor colorWithRed:0.75 green:0.75 blue:0.75 alpha:1.0];
    
    self.navigationItem.leftBarButtonItem = self.customBackButton;
    self.navigationItem.rightBarButtonItem = self.customPostButton;

    if(self.shouldReloadOnViewLoad) {
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

/*
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AwfulThreadDidUpdateNotification
                                                  object:nil];
}
*/

-(BOOL)shouldReloadOnViewLoad
{
    //check date on last thread we've got, if older than 10? min reload
    NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:@"AwfulThread"];
    req.predicate = [NSPredicate predicateWithFormat:@"forum = %@", self.forum];
    req.sortDescriptors = [[NSSortDescriptor sortDescriptorWithKey:@"lastPostDate" ascending:NO] wrapInArray];
    req.fetchLimit = 1;
    
    NSArray* newestThread = [ApplicationDelegate.managedObjectContext executeFetchRequest:req error:nil];
    if (newestThread.count == 1) {
        NSDate *date = [[newestThread objectAtIndex:0] lastPostDate];

        if (-[date timeIntervalSinceNow] > (60*10.0)+60*60) { //dst issue here or something, thread date an hour behind
            return YES;
        }
    }
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
        NSUInteger index = [self.fetchedResultsController.fetchedObjects indexOfObject:thread];
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

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    
    [self.navigationController setToolbarHidden:YES];
    
    [self.navigationController.navigationBar setBackgroundImage:[self customNavigationBarBackgroundImageForMetrics:(UIBarMetricsDefault)] 
                                                  forBarMetrics:(UIBarMetricsDefault)];
     
}

-(UIBarButtonItem*) customPostButton {
    return [[UIBarButtonItem alloc] initWithBarButtonSystemItem:(UIBarButtonSystemItemCompose)
                                                         target:self
                                                         action:@selector(didTapCompose:)
            ];
}


-(UIImage*) customNavigationBarBackgroundImageForMetrics:(UIBarMetrics)metrics {
    return [ApplicationDelegate navigationBarBackgroundImageForMetrics:metrics];
}

-(AwfulThread *)getThreadAtIndexPath : (NSIndexPath *)path
{    
    return [self.fetchedResultsController objectAtIndexPath:path];
}

-(void) pop {
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - Table view data source and delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulThread* thread = [self.fetchedResultsController objectAtIndexPath:indexPath];
    return [AwfulThreadCell heightForContent:thread inTableView:self.tableView];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString* identifier = [AwfulCustomForums cellIdentifierForForum:self.forum];
    AwfulThreadCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [AwfulCustomForums cellForIdentifier:identifier];
    
    [self configureCell:cell atIndexPath:indexPath];
    //cell.threadListController = self;
    
    return cell;
}

- (void)configureCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath *)indexPath {
    AwfulThread *thread = [self getThreadAtIndexPath:indexPath];
    [(AwfulThreadCell*)cell configureForThread:thread];
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

#pragma mark selection
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
    //[self performSegueWithIdentifier:@"AwfulPage" 
    //                          sender:[self.tableView cellForRowAtIndexPath:indexPath]];
    
    //preload the page before pushing it
    AwfulThread *thread = [self.fetchedResultsController objectAtIndexPath:indexPath];
    AwfulPage *page = [[UIStoryboard storyboardWithName:@"Main" bundle:[NSBundle mainBundle]] instantiateViewControllerWithIdentifier:@"AwfulPage"];
    page.thread = thread;
    [page refresh];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:AwfulPageWillLoadNotification
                                                        object:[self getThreadAtIndexPath:indexPath]];
    
    
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(didLoadThreadPage:) 
                                                 name:AwfulPageDidLoadNotification 
                                               object:thread
     ];
}

-(void) didLoadThreadPage:(NSNotification*)msg {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    AwfulPage* page = [msg.userInfo objectForKey:@"page"];
    
    if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        UINavigationController *nav = [self.splitViewController.viewControllers objectAtIndex:1];
        [nav setViewControllers:[NSArray arrayWithObject:page] animated:YES];
        /*
        [self.splitViewController setViewControllers:[NSArray arrayWithObjects:
                                                      [self.splitViewController.viewControllers objectAtIndex:0],
                                                      page,
                                                      nil]
         ];*/
    }
    else
        [self.navigationController pushViewController:page animated:YES];
}
@end
