//  AwfulBookmarkedThreadTableViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulBookmarkedThreadTableViewController.h"
#import "AwfulAlertView.h"
#import "AwfulHTTPClient.h"
#import "AwfulModels.h"
#import "AwfulThreadCell.h"
#import <SVPullToRefresh/SVPullToRefresh.h>

@implementation AwfulBookmarkedThreadTableViewController
{
    NSInteger _mostRecentlyLoadedPage;
    UIBarButtonItem *_backBarItem;
}

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    if (!(self = [super initWithNibName:Nil bundle:nil])) return nil;
    _managedObjectContext = managedObjectContext;
    self.title = @"Bookmarks";
    self.tabBarItem.image = [UIImage imageNamed:@"bookmarks"];
    self.navigationItem.backBarButtonItem = [UIBarButtonItem emptyBackBarButtonItem];
    return self;
}

- (UIBarButtonItem *)backBarItem
{
    if (_backBarItem) return _backBarItem;
    _backBarItem = [[UIBarButtonItem alloc] initWithImage:self.tabBarItem.image
                                      landscapeImagePhone:[UIImage imageNamed:@"bookmarks-landscape"]
                                                    style:UIBarButtonItemStylePlain
                                                   target:nil
                                                   action:nil];
    return _backBarItem;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:AwfulThread.entityName];
    request.predicate = [NSPredicate predicateWithFormat:@"bookmarked = YES"];
    request.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"lastPostDate" ascending:NO] ];
    self.threadDataSource.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                                         managedObjectContext:self.managedObjectContext
                                                                                           sectionNameKeyPath:nil
                                                                                                    cacheName:nil];
    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    __weak __typeof__(self) weakSelf = self;
    [self.tableView addInfiniteScrollingWithActionHandler:^{
        __typeof__(self) self = weakSelf;
        [self loadPage:self->_mostRecentlyLoadedPage + 1];
    }];
    self.tableView.showsInfiniteScrolling = NO;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if ([self shouldRefreshOnAppear]) {
        [self refresh];
    }
}

- (BOOL)shouldRefreshOnAppear
{
    if (!AwfulHTTPClient.client.reachable) return NO;
    if ([self.tableView numberOfRowsInSection:0] == 0) return YES;
    if (!self.lastRefreshDate) return YES;
    return [[NSDate date] timeIntervalSinceDate:self.lastRefreshDate] > 60 * 10;
}

- (NSDate *)lastRefreshDate
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:kLastBookmarksRefreshDate];
}

- (void)setLastRefreshDate:(NSDate *)date
{
    [[NSUserDefaults standardUserDefaults] setObject:date forKey:kLastBookmarksRefreshDate];
}

static NSString * const kLastBookmarksRefreshDate = @"com.awfulapp.Awful.LastBookmarksRefreshDate";

- (void)refresh
{
    [self.refreshControl beginRefreshing];
    [self loadPage:1];
}

- (void)loadPage:(NSInteger)page
{
    __weak __typeof__(self) weakSelf = self;
    [AwfulHTTPClient.client listBookmarkedThreadsOnPage:page andThen:^(NSError *error, NSArray *threads) {
        __typeof__(self) self = weakSelf;
        if (error) {
            [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
        } else {
            [self.tableView beginUpdates];
            [threads setValue:@YES forKey:@"bookmarked"];
            if (page == 1) {
                NSArray *threadIDsToIgnore = [threads valueForKey:@"threadID"];
                NSArray *threadsToForget = [AwfulThread fetchAllInManagedObjectContext:self.managedObjectContext
                                                               matchingPredicateFormat:@"bookmarked = YES && NOT(threadID IN %@)", threadIDsToIgnore];
                [threadsToForget setValue:@NO forKey:@"bookmarked"];
            }
            [self.tableView endUpdates];
            [self setLastRefreshDate:[NSDate date]];
        }
        [self.refreshControl endRefreshing];
        [self.tableView.infiniteScrollingView stopAnimating];
        self.tableView.showsInfiniteScrolling = threads.count >= 40;
    }];
}

@end
