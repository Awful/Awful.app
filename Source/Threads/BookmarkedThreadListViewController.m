//  BookmarkedThreadListViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "BookmarkedThreadListViewController.h"
#import "AwfulForumsClient.h"
#import "AwfulModels.h"
#import "AwfulRefreshMinder.h"
#import "AwfulSettings.h"
#import "Handoff.h"
#import <SVPullToRefresh/SVPullToRefresh.h>
#import "Awful-Swift.h"

@interface BookmarkedThreadListViewController ()

@property (assign, nonatomic) NSUInteger mostRecentlyLoadedPage;

@end

@implementation BookmarkedThreadListViewController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self) return nil;
    
    _managedObjectContext = managedObjectContext;
    self.title = @"Bookmarks";
    self.tabBarItem.image = [UIImage imageNamed:@"bookmarks"];
    self.navigationItem.backBarButtonItem = [UIBarButtonItem awful_emptyBackBarButtonItem];
    
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self configureFetchedResultsController];

    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    __weak __typeof__(self) weakSelf = self;
    [self.tableView addInfiniteScrollingWithActionHandler:^{
        __typeof__(self) self = weakSelf;
        [self loadPage:self.mostRecentlyLoadedPage + 1];
    }];
    self.tableView.showsInfiniteScrolling = NO;
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(settingsDidChange:)
                                                 name:AwfulSettingsDidChangeNotification
                                               object:nil];
}

- (void)configureFetchedResultsController
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:[AwfulThread entityName]];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"bookmarked = YES"];
    NSMutableArray *sortDescriptors = [NSMutableArray new];
    if ([AwfulSettings sharedSettings].bookmarksSortedByUnread) {
        [sortDescriptors addObject:[NSSortDescriptor sortDescriptorWithKey:@"anyUnreadPosts" ascending:NO]];
	}
    [sortDescriptors addObject:[NSSortDescriptor sortDescriptorWithKey:@"lastPostDate" ascending:NO]];
    fetchRequest.sortDescriptors = sortDescriptors;
    fetchRequest.fetchBatchSize = 20;
    self.threadDataSource.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                                         managedObjectContext:self.managedObjectContext
                                                                                           sectionNameKeyPath:nil
                                                                                                    cacheName:nil];
}

- (void)settingsDidChange:(NSNotification *)note
{
    if ([note.userInfo[AwfulSettingsDidChangeSettingKey] isEqual:AwfulSettingsKeys.bookmarksSortedByUnread]) {
        [self configureFetchedResultsController];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self refreshIfNecessary];
    self.userActivity = [[NSUserActivity alloc] initWithActivityType:HandoffActivityTypeListingThreads];
    self.userActivity.needsSave = YES;
}

- (void)refreshIfNecessary
{
    if (![AwfulForumsClient client].reachable) return;
    
    if ([self.tableView numberOfRowsInSection:0] == 0 || [[AwfulRefreshMinder minder] shouldRefreshBookmarks]) {
        [self refresh];
    }
}

- (void)refresh
{
    [self.refreshControl beginRefreshing];
    [self loadPage:1];
}

- (void)loadPage:(NSInteger)page
{
    __weak __typeof__(self) weakSelf = self;
    [[AwfulForumsClient client] listBookmarkedThreadsOnPage:page andThen:^(NSError *error, NSArray *threads) {
        __typeof__(self) self = weakSelf;
        if (error) {
            [self presentViewController:[UIAlertController alertWithNetworkError:error] animated:YES completion:nil];
        } else {
            [[AwfulRefreshMinder minder] didFinishRefreshingBookmarks];
            self.mostRecentlyLoadedPage = page;
        }
        [self.refreshControl endRefreshing];
        [self.tableView.infiniteScrollingView stopAnimating];
        self.tableView.showsInfiniteScrolling = threads.count >= 40;
    }];
}

- (void)updateUserActivityState:(NSUserActivity *)activity
{
    activity.title = @"Bookmarked Threads";
    [activity addUserInfoEntriesFromDictionary:@{HandoffInfoBookmarksKey: @YES}];
    activity.webpageURL = [NSURL URLWithString:@"/bookmarkthreads.php" relativeToURL:[AwfulForumsClient client].baseURL];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    self.userActivity = nil;
}

#pragma mark - AwfulFetchedResultsControllerDataSourceDelegate

- (BOOL)canDeleteObject:(id)object atIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)deleteObject:(AwfulThread *)thread
{
    [[AwfulForumsClient client] setThread:thread isBookmarked:NO andThen:^(NSError *error) {
        if (error) {
            [self presentViewController:[UIAlertController alertWithNetworkError:error] animated:YES completion:nil];
        } else {
            thread.bookmarked = NO;
            if (![thread.managedObjectContext save:&error]) {
                NSLog(@"%s error saving managed object context: %@", __PRETTY_FUNCTION__, error);
            }
        }
    }];
}

#pragma mark - UITableViewDelegate

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return @"Remove";
}

@end
