//
//  AwfulThreadListController.m
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThreadListController.h"
#import "AwfulFetchedTableViewControllerSubclass.h"
#import "AwfulActionSheet.h"
#import "AwfulAppDelegate.h"
#import "AwfulDataStack.h"
#import "AwfulHTTPClient.h"
#import "AwfulLoginController.h"
#import "AwfulModels.h"
#import "AwfulPage.h"
#import "AwfulSettings.h"
#import "AwfulThreadCell.h"
#import "AwfulThreadTags.h"
#import "SVPullToRefresh.h"

typedef enum {
    AwfulThreadListActionsTypeFirstPage = 0,
    AwfulThreadListActionsTypeLastPage,
    AwfulThreadListActionsTypeUnread
} AwfulThreadListActionsType;


@interface AwfulThreadListController ()

@property (nonatomic) NSMutableDictionary *cellsWithoutThreadTags;

@property (nonatomic) BOOL listeningForNewThreadTags;

@end


@implementation AwfulThreadListController

- (id)init
{
    self = [super init];
    if (self) {
        _cellsWithoutThreadTags = [NSMutableDictionary new];
    }
    return self;
}

- (NSFetchedResultsController *)createFetchedResultsController
{
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:[AwfulThread entityName]];
    request.predicate = [NSPredicate predicateWithFormat:@"hideFromList == NO AND forum == %@",
                         self.forum];
    request.sortDescriptors = @[
        [NSSortDescriptor sortDescriptorWithKey:@"stickyIndex" ascending:YES],
        [NSSortDescriptor sortDescriptorWithKey:@"lastPostDate" ascending:NO]
    ];
    return [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                               managedObjectContext:[AwfulDataStack sharedDataStack].context
                                                 sectionNameKeyPath:nil
                                                          cacheName:nil];
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
    id op = [[AwfulHTTPClient client] listThreadsInForumWithID:self.forum.forumID
                                                        onPage:pageNum
                                                       andThen:^(NSError *error, NSArray *threads)
    {
        if (error) {
            [[AwfulAppDelegate instance] requestFailed:error];
        } else {
            if (pageNum == 1) {
                [self.forum.threads setValue:@YES forKey:@"hideFromList"];
            }
            [threads setValue:@NO forKey:@"hideFromList"];
            [[AwfulDataStack sharedDataStack] save];
            self.currentPage = pageNum;
        }
        [self finishedRefreshing];
    }];
    self.networkOperation = op;
}

- (void)newlyVisible
{
    //For subclassing
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.currentPage = 1;
    
    UILabel *label = (UILabel *)self.navigationItem.titleView;
    label.numberOfLines = 2;
    label.text = self.forum.name;
    
    self.tableView.separatorColor = [UIColor colorWithWhite:0.75 alpha:1];
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
    AwfulActionSheet *sheet = [[AwfulActionSheet alloc] initWithTitle:thread.title];
    [sheet addButtonWithTitle:@"Jump to First Page" block:^{
        AwfulPage *page = [AwfulPage newDeviceSpecificPage];
        page.thread = thread;
        page.destinationType = AwfulPageDestinationTypeFirst;
        [self displayPage:page];
        [page loadPageNum:1];
    }];
    [sheet addButtonWithTitle:@"Jump to Last Page" block:^{
        AwfulPage *page = [AwfulPage newDeviceSpecificPage];
        page.thread = thread;
        page.destinationType = AwfulPageDestinationTypeLast;
        [self displayPage:page];
        [page loadPageNum:AwfulPageLast];
    }];
    [sheet addButtonWithTitle:@"Mark as Unread" block:^{
        [self markThreadUnseen:thread];
    }];
    [sheet addCancelButtonWithTitle:@"Cancel"];
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [sheet showFromTabBar:self.tabBarController.tabBar];
    } else if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        NSUInteger index = [self.fetchedResultsController.fetchedObjects indexOfObject:thread];
        if (index != NSNotFound) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
            [sheet showFromRect:cell.frame inView:self.tableView animated:YES];
        }
    }
}

- (void)markThreadUnseen:(AwfulThread *)thread
{
    [[AwfulHTTPClient client] forgetReadPostsInThreadWithID:thread.threadID
                                                    andThen:^(NSError *error)
    {
        if (error) {
            [[AwfulAppDelegate instance] requestFailed:error];
        } else {
            thread.totalUnreadPostsValue = -1;
            [[AwfulDataStack sharedDataStack] save];
        }
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
        AwfulSplitViewController *split = (AwfulSplitViewController *)self.splitViewController;
        [split ensureLeftBarButtonItemOnDetailView];
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
    cell.imageView.image = [[AwfulThreadTags sharedThreadTags] threadTagNamed:thread.firstIconName];
    if (!cell.imageView.image) {
        [self updateThreadTag:thread.firstIconName forCellAtIndexPath:indexPath];
    }
    cell.sticky = thread.isStickyValue;
    cell.closed = thread.isClosedValue;
    // Hardcode Film Dump to never show ratings; its thread tags are the ratings.
    if ([thread.forum.forumID isEqualToString:@"133"]) {
        cell.rating = 0;
    } else {
        cell.rating = [thread.threadRating floatValue];
    }
    cell.textLabel.text = thread.title;
    NSString *pagesFormatted = [NSNumberFormatter localizedStringFromNumber:thread.numberOfPages
                                                                numberStyle:NSNumberFormatterDecimalStyle];
    NSString *plural = thread.numberOfPagesValue == 1 ? @"" : @"s";
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ page%@", pagesFormatted, plural];
    cell.originalPosterTextLabel.text = [NSString stringWithFormat:@"Posted by %@", thread.authorName];
    cell.unreadCountBadgeView.badgeText = [thread.totalUnreadPosts stringValue];
    cell.unreadCountBadgeView.on = thread.totalUnreadPostsValue > 0;
    cell.showsUnread = thread.totalUnreadPostsValue != -1;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
}

- (void)updateThreadTag:(NSString *)threadTagName forCellAtIndexPath:(NSIndexPath *)indexPath
{
    self.cellsWithoutThreadTags[indexPath] = threadTagName;
    if (self.listeningForNewThreadTags) return;
    self.listeningForNewThreadTags = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(newThreadTags:)
                                                 name:AwfulNewThreadTagsAvailableNotification
                                               object:nil];
}

- (void)newThreadTags:(NSNotification *)note
{
    NSMutableArray *updated = [NSMutableArray new];
    for (NSIndexPath *indexPath in self.cellsWithoutThreadTags) {
        NSString *tag = self.cellsWithoutThreadTags[indexPath];
        UIImage *image = [[AwfulThreadTags sharedThreadTags] threadTagNamed:tag];
        if (!image) continue;
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        cell.imageView.image = image;
        [updated addObject:indexPath];
    }
    [self.tableView reloadRowsAtIndexPaths:updated withRowAnimation:UITableViewRowAnimationNone];
    [self.cellsWithoutThreadTags removeObjectsForKeys:updated];
    if ([self.cellsWithoutThreadTags count] == 0) {
        self.listeningForNewThreadTags = NO;
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AwfulNewThreadTagsAvailableNotification
                                                      object:nil];
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
    AwfulPage *page = [AwfulPage newDeviceSpecificPage];
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
        AwfulSplitViewController *split = (AwfulSplitViewController *)self.splitViewController;
        [split ensureLeftBarButtonItemOnDetailView];
        [split.masterPopoverController dismissPopoverAnimated:YES];
        [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow animated:YES];
    } else {
        [self.navigationController pushViewController:page animated:YES];
    }
}

@end
