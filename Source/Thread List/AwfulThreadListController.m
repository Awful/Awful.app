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
#import "SVPullToRefresh.h"
#import "AwfulCSSTemplate.h"

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
    
    AwfulThread *thread = [self.fetchedResultsController objectAtIndexPath:selected];
    page.thread = thread;
    [page refresh];
    
    if (self.splitViewController) {
        [self.splitViewController prepareForSegue:segue sender:sender];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:AwfulPageWillLoadNotification
                                                        object:thread];
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
    
    self.tableView.separatorColor = [UIColor colorWithWhite:0.75 alpha:1];
    self.tableView.backgroundColor = [UIColor colorWithRed:0.859 green:0.910 blue:0.957 alpha:1];
    self.tableView.rowHeight = 75;

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
    NSString *board = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? @"MainiPad" : @"Main";
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:board bundle:nil];
    if (buttonIndex == AwfulThreadListActionsTypeFirstPage) {
        AwfulPage *page = [storyboard instantiateViewControllerWithIdentifier:@"AwfulPage"];
        page.thread = self.heldThread;
        page.destinationType = AwfulPageDestinationTypeFirst;
        [self displayPage:page];
        [page loadPageNum:1];
        
    } else if (buttonIndex == AwfulThreadListActionsTypeLastPage) {
        AwfulPage *page = [storyboard instantiateViewControllerWithIdentifier:@"AwfulPage"];
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

- (void)pop
{
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - Table view data source and delegate

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * const Identifier = @"AwfulThreadCell";
    AwfulThreadCell *cell = [tableView dequeueReusableCellWithIdentifier:Identifier];
    if (!cell) {
        cell = [[AwfulThreadCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:Identifier];
        UILongPressGestureRecognizer *longPress = [UILongPressGestureRecognizer new];
        [longPress addTarget:self action:@selector(showThreadActions:)];
        [cell addGestureRecognizer:longPress];
    }
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(UITableViewCell *)genericCell atIndexPath:(NSIndexPath *)indexPath
{
    AwfulThreadCell *cell = (AwfulThreadCell *)genericCell;
    AwfulThread *thread = [self.fetchedResultsController objectAtIndexPath:indexPath];
    // TODO handle tags we don't ship
    cell.threadTagImageView.image = [UIImage imageNamed:[thread.firstIconURL lastPathComponent]];
    [cell setSticky:thread.stickyIndexValue != NSNotFound];
    [cell setRating:[thread.threadRating floatValue]];
    cell.textLabel.text = thread.title;
    NSInteger numberOfPages = thread.totalRepliesValue / 40 + 1;
    NSString *pagesFormatted = [NSNumberFormatter localizedStringFromNumber:@(numberOfPages)
                                                                numberStyle:NSNumberFormatterDecimalStyle];
    NSString *plural = numberOfPages == 1 ? @"" : @"s";
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ page%@", pagesFormatted, plural];
    cell.originalPosterTextLabel.text = thread.authorName;
    cell.unreadCountBadgeView.badgeText = [thread.totalUnreadPosts stringValue];
    cell.unreadCountBadgeView.on = thread.totalUnreadPostsValue > 0;
    cell.showsUnread = thread.totalUnreadPostsValue != -1;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
}

- (void)showThreadActions:(UILongPressGestureRecognizer *)longPress
{
    if (longPress.state == UIGestureRecognizerStateBegan) {
        UITableViewCell *cell = (UITableViewCell *)longPress.view;
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        AwfulThread *thread = [self.fetchedResultsController objectAtIndexPath:indexPath];
        [self showThreadActionsForThread:thread];
    }
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulThread *thread = [self.fetchedResultsController objectAtIndexPath:indexPath];
    return (thread.totalUnreadPostsValue >= 0);
}

- (NSString *)tableView:(UITableView *)tableView
    titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return @"Mark Unread";
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
    forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        AwfulThread *thread = [self.fetchedResultsController objectAtIndexPath:indexPath];
        [self markThreadUnseen:thread];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
    //preload the page before pushing it
    NSString *board = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? @"MainiPad" : @"Main";
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:board bundle:nil];
    AwfulPage *page = [storyboard instantiateViewControllerWithIdentifier:@"AwfulPage"];
    AwfulThread *thread = [self.fetchedResultsController objectAtIndexPath:indexPath];
    page.thread = thread;
    [page refresh];
    [[NSNotificationCenter defaultCenter] postNotificationName:AwfulPageWillLoadNotification
                                                        object:thread];
    [[NSNotificationCenter defaultCenter] addObserver:self 
                                             selector:@selector(didLoadThreadPage:) 
                                                 name:AwfulPageDidLoadNotification 
                                               object:thread];
}

- (void)didLoadThreadPage:(NSNotification *)msg
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    AwfulPage *page = [msg.userInfo objectForKey:@"page"];
    
    if (self.splitViewController) {
        UINavigationController *nav = self.splitViewController.viewControllers[1];
        [nav setViewControllers:@[page] animated:YES];
        if ([self.splitViewController isKindOfClass:[AwfulSplitViewController class]]) {
            AwfulSplitViewController *svc = (AwfulSplitViewController *)self.splitViewController;
            [svc.masterPopoverController dismissPopoverAnimated:YES];
        }
        [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
    }
    else {
        [self.navigationController pushViewController:page animated:YES];
    }
}

@end
