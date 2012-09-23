//
//  AwfulThreadList.m
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThreadListController.h"
#import "AwfulFetchedTableViewControllerSubclass.h"
#import "AwfulAppDelegate.h"
#import "AwfulPage.h"
#import "AwfulSettings.h"
#import "AwfulThread+AwfulMethods.h"
#import "AwfulThreadCell.h"
#import "AwfulLoginController.h"
#import "AwfulCustomForums.h"
#import "SVPullToRefresh.h"

typedef enum {
    AwfulThreadListActionsTypeFirstPage = 0,
    AwfulThreadListActionsTypeLastPage,
    AwfulThreadListActionsTypeUnread
} AwfulThreadListActionsType;

@implementation AwfulThreadListController

- (NSFetchedResultsController *)createFetchedResultsController
{
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:[AwfulThread entityName]];
    request.predicate = [NSPredicate predicateWithFormat:@"forum = %@", self.forum];
    request.sortDescriptors = @[
        [NSSortDescriptor sortDescriptorWithKey:@"stickyIndex" ascending:YES],
        [NSSortDescriptor sortDescriptorWithKey:@"lastPostDate" ascending:NO]
    ];
    return [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                               managedObjectContext:ApplicationDelegate.managedObjectContext
                                                 sectionNameKeyPath:nil
                                                          cacheName:nil];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
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

- (void)setForum:(AwfulForum *)forum
{
    if (_forum == forum) return;
    _forum = forum;
    self.title = _forum.name;
    self.fetchedResultsController = [self createFetchedResultsController];
}

#pragma mark - Table view controller

- (void)refresh
{   
    [super refresh];
    [self loadPageNum:1];
}

- (BOOL)canPullForNextPage
{
    return YES;
}

- (void)nextPage
{
    [super nextPage];
    [self loadPageNum:self.currentPage + 1];
}

- (void)stop
{
    [self.networkOperation cancel];
    [self finishedRefreshing];
}

- (void)finishedRefreshing
{
    [super finishedRefreshing];
    self.isLoading = NO;
}

- (void)loadPageNum:(NSUInteger)pageNum
{    
    [self.networkOperation cancel];
    self.isLoading = YES;
    self.networkOperation = [[AwfulHTTPClient sharedClient] threadListForForum:self.forum
                                                                       pageNum:pageNum
                                                                  onCompletion:^(id _)
    {
        self.currentPage = pageNum;
        [self finishedRefreshing];
    } onError:^(NSError *error)
    {
        [self finishedRefreshing];
        [ApplicationDelegate requestFailed:error];
    }];
}

- (void)newlyVisible
{
    //For subclassing
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.currentPage = 1;
    self.title = self.forum.name;
    
    UILabel *label = (UILabel *)self.navigationItem.titleView;
    label.numberOfLines = 2;
    label.text = self.forum.name;
    
    self.tableView.separatorColor = [UIColor colorWithRed:0.75 green:0.75 blue:0.75 alpha:1.0];

    if (self.fetchedResultsController.fetchedObjects.count == 0 && IsLoggedIn()) {
        [self refresh];
    }
}

- (BOOL)shouldReloadOnViewLoad
{
    //check date on last thread we've got, if older than 10? min reload
    return NO;
}

- (void)showThreadActionsForThread:(AwfulThread *)thread
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

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == AwfulThreadListActionsTypeFirstPage) {
        AwfulPage *page = [self.storyboard instantiateViewControllerWithIdentifier:@"AwfulPage"];
        page.thread = self.heldThread;
        page.destinationType = AwfulPageDestinationTypeFirst;
        [self displayPage:page];
        [page loadPageNum:1];
        
    } else if (buttonIndex == AwfulThreadListActionsTypeLastPage) {
        AwfulPage *page = [self.storyboard instantiateViewControllerWithIdentifier:@"AwfulPage"];
        page.thread = self.heldThread;
        page.destinationType = AwfulPageDestinationTypeLast;
        [self displayPage:page];
        [page loadPageNum:0];
        
    } else if (buttonIndex == AwfulThreadListActionsTypeUnread) {
        [self markThreadUnseen:self.heldThread];

    }
}

- (void)markThreadUnseen:(AwfulThread *)thread
{
    [[AwfulHTTPClient sharedClient] markThreadUnseen:thread onCompletion:^(void)
    {
        thread.totalUnreadPosts = [NSNumber numberWithInt:-1];
        [ApplicationDelegate saveContext];
        
    } onError:^(NSError *error)
    {
        [ApplicationDelegate requestFailed:error];
    }];
}

- (void)displayPage:(AwfulPage *)page
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [self.navigationController pushViewController:page animated:YES];
    } else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        NSMutableArray *vcs = [NSMutableArray arrayWithArray:self.splitViewController.viewControllers];
        [vcs removeLastObject];
        
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:page];
        [vcs addObject:nav];
        self.splitViewController.viewControllers = vcs;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationItem.leftBarButtonItem = self.customBackButton;
    
    [self.navigationController setToolbarHidden:YES];
    
    [self.navigationController.navigationBar setBackgroundImage:[self customNavigationBarBackgroundImageForMetrics:(UIBarMetricsDefault)] 
                                                  forBarMetrics:(UIBarMetricsDefault)];
     
}

- (UIImage *)customNavigationBarBackgroundImageForMetrics:(UIBarMetrics)metrics
{
    return [ApplicationDelegate navigationBarBackgroundImageForMetrics:metrics];
}

- (AwfulThread *)getThreadAtIndexPath:(NSIndexPath *)path
{    
    return [self.fetchedResultsController objectAtIndexPath:path];
}

- (void)pop
{
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - Table view data source and delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulThread* thread = [self.fetchedResultsController objectAtIndexPath:indexPath];
    return [AwfulThreadCell heightForContent:thread inTableView:self.tableView];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSString* identifier = [AwfulCustomForums cellIdentifierForForum:self.forum];
    AwfulThreadCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (!cell) cell = [AwfulCustomForums cellForIdentifier:identifier];
    
    [self configureCell:cell atIndexPath:indexPath];
    
    return cell;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    AwfulThread *thread = [self getThreadAtIndexPath:indexPath];
    [(AwfulThreadCell*)cell configureForThread:thread];
}

#pragma mark table editing to mark cells unread

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulThread *thread = [self getThreadAtIndexPath:indexPath];
    return (thread.totalUnreadPostsValue >= 0);
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return @"Mark Unread";
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        AwfulThread *thread = [self getThreadAtIndexPath:indexPath];
        [self markThreadUnseen:thread];
    }
}

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

- (void)didLoadThreadPage:(NSNotification *)msg
{
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
    else {
        [self.navigationController pushViewController:page animated:YES];
    }
}

@end
