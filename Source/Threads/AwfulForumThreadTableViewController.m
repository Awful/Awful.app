//  AwfulForumThreadTableViewController.m
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulForumThreadTableViewController.h"
#import "AwfulActionSheet.h"
#import "AwfulAlertView.h"
#import "AwfulAppDelegate.h"
#import "AwfulExpandingSplitViewController.h"
#import "AwfulFetchedResultsControllerDataSource.h"
#import "AwfulHTTPClient.h"
#import "AwfulIconActionSheet.h"
#import "AwfulLoginController.h"
#import "AwfulModels.h"
#import "AwfulPostsViewController.h"
#import "AwfulProfileViewController.h"
#import "AwfulSettings.h"
#import "AwfulThreadCell.h"
#import "AwfulThreadComposeViewController.h"
#import "AwfulThreadTags.h"
#import "awfulUIKitAndFoundationCategories.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import <SVPullToRefresh/SVPullToRefresh.h>

@interface AwfulForumThreadTableViewController () <AwfulThreadComposeViewControllerDelegate, UIViewControllerRestoration>

@property (strong, nonatomic) UIBarButtonItem *newThreadButtonItem;
@property (strong, nonatomic) UIBarButtonItem *abbreviatedBackButtonItem;
@property (strong, nonatomic) AwfulThreadComposeViewController *composeViewController;

@end

@implementation AwfulForumThreadTableViewController
{
    NSFetchedResultsController *_fetchedResultsController;
    NSInteger _mostRecentlyLoadedPage;
}

- (id)initWithForum:(AwfulForum *)forum
{
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    _forum = forum;
    self.title = _forum.name;
    self.navigationItem.backBarButtonItem = self.abbreviatedBackButtonItem;
    self.navigationItem.rightBarButtonItem = self.newThreadButtonItem;
    return self;
}

- (UIBarButtonItem *)newThreadButtonItem
{
    if (_newThreadButtonItem) return _newThreadButtonItem;
    _newThreadButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose
                                                                         target:self
                                                                         action:@selector(didTapNewThreadButtonItem)];
    return _newThreadButtonItem;
}

- (void)didTapNewThreadButtonItem
{
    self.composeViewController = [[AwfulThreadComposeViewController alloc] initWithForum:self.forum];
    self.composeViewController.restorationIdentifier = @"Compose thread view";
    self.composeViewController.delegate = self;
    UINavigationController *nav = [self.composeViewController enclosingNavigationController];
    nav.restorationIdentifier = @"Compose thread navigation view";
    [self presentViewController:nav animated:YES completion:nil];
}

- (UIBarButtonItem *)abbreviatedBackButtonItem
{
    if (_abbreviatedBackButtonItem) return _abbreviatedBackButtonItem;
    _abbreviatedBackButtonItem = [[UIBarButtonItem alloc] initWithTitle:self.forum.abbreviatedName
                                                                  style:UIBarButtonItemStylePlain
                                                                 target:nil
                                                                 action:nil];
    return _abbreviatedBackButtonItem;
}

- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController) return _fetchedResultsController;
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:AwfulThread.entityName];
    request.predicate = [NSPredicate predicateWithFormat:@"hideFromList == NO AND forum == %@", self.forum];
    request.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"stickyIndex" ascending:YES],
                                 [NSSortDescriptor sortDescriptorWithKey:@"lastPostDate" ascending:NO] ];
    NSManagedObjectContext *context = self.forum.managedObjectContext;
    _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                    managedObjectContext:context
                                                                      sectionNameKeyPath:nil
                                                                               cacheName:nil];
    return _fetchedResultsController;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    if (self.fetchedResultsController.fetchedObjects.count > 0) {
        [self enableInfiniteScrolling];
    }
}

- (void)enableInfiniteScrolling
{
    __weak __typeof__(self) weakSelf = self;
    [self.tableView addInfiniteScrollingWithActionHandler:^{
        __typeof__(self) self = weakSelf;
        [self loadPage:self->_mostRecentlyLoadedPage + 1];
    }];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if ([self shouldRefreshOnAppear]) {
        [self refresh];
    }
    if (self.fetchedResultsController.fetchedObjects.count > 0) {
        [self enableInfiniteScrolling];
    }
}

- (BOOL)shouldRefreshOnAppear
{
    if (![AwfulHTTPClient client].reachable) return NO;
    if (!self.forum.lastRefresh) return YES;
    if ([self.fetchedResultsController.fetchedObjects count] == 0) return YES;
    return [[NSDate date] timeIntervalSinceDate:self.forum.lastRefresh] > 60 * 15;
}

- (void)refresh
{
    [self.refreshControl beginRefreshing];
    [self loadPage:1];
}

- (void)loadPage:(NSInteger)page
{
    __weak __typeof__(self) weakSelf = self;
    [AwfulHTTPClient.client listThreadsInForumWithID:self.forum.forumID onPage:page andThen:^(NSError *error, NSArray *threads) {
        __typeof__(self) self = weakSelf;
        if (error) {
            [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
        } else {
            if (page == 1) {
                NSMutableSet *threadsToHide = [self.forum.threads mutableCopy];
                for (AwfulThread *thread in threads) {
                    [threadsToHide removeObject:thread];
                }
                [threadsToHide setValue:@YES forKey:@"hideFromList"];
                [self enableInfiniteScrolling];
            }
            [threads setValue:@NO forKey:@"hideFromList"];
            self.forum.lastRefresh = [NSDate date];
            NSError *error;
            BOOL ok = [self.forum.managedObjectContext save:&error];
            if (!ok) {
                NSLog(@"%s error saving managed object context while loading %@ page %tu: %@",
                      __PRETTY_FUNCTION__, self.forum.name, page, error);
            }
        }
        _mostRecentlyLoadedPage = page;
        [self.refreshControl endRefreshing];
        [self.tableView.infiniteScrollingView stopAnimating];
    }];
}

#pragma mark - AwfulThreadTableViewController

- (AwfulTheme *)theme
{
    return [AwfulTheme currentThemeForForum:self.forum];
}

#pragma mark - AwfulFetchedResultsControllerDataSource

- (void)configureCell:(AwfulThreadCell *)cell withObject:(AwfulThread *)thread
{
    [super configureCell:cell withObject:thread];
    if (thread.sticky) {
        cell.stickyImageView.image = [UIImage imageNamed:@"sticky"];
    } else {
        cell.stickyImageView.image = nil;
    }
}

#pragma mark - AwfulThreadComposeViewControllerDelegate

- (void)threadComposeController:(AwfulThreadComposeViewController *)controller
            didPostThreadWithID:(NSString *)threadID
{
    self.composeViewController = nil;
    [self dismissViewControllerAnimated:YES completion:nil];
    AwfulThread *thread = [AwfulThread firstOrNewThreadWithThreadID:threadID
                                             inManagedObjectContext:self.forum.managedObjectContext];
    AwfulPostsViewController *postsViewController = [[AwfulPostsViewController alloc] initWithThread:thread];
    postsViewController.restorationIdentifier = @"AwfulPostsViewController";
    postsViewController.page = 1;
    [self showPostsViewController:postsViewController];
}

- (void)threadComposeControllerDidCancel:(AwfulThreadComposeViewController *)controller
{
    // TODO save draft?
    self.composeViewController = nil;
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - State preservation and restoration

+ (UIViewController *)viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    AwfulForum *forum = [AwfulForum fetchArbitraryInManagedObjectContext:AwfulAppDelegate.instance.managedObjectContext
                                                 matchingPredicateFormat:@"forumID = %@", [coder decodeObjectForKey:ForumIDKey]];
    AwfulForumThreadTableViewController *threadTableViewController = [[self alloc] initWithForum:forum];
    threadTableViewController.restorationIdentifier = identifierComponents.lastObject;
    threadTableViewController.restorationClass = self;
    return threadTableViewController;
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeObject:self.forum.forumID forKey:ForumIDKey];
    [coder encodeObject:self.composeViewController forKey:ComposeViewControllerKey];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];
    self.composeViewController = [coder decodeObjectForKey:ComposeViewControllerKey];
    self.composeViewController.delegate = self;
}

static NSString * const ForumIDKey = @"AwfulForumID";
static NSString * const ComposeViewControllerKey = @"AwfulComposeViewController";

@end
