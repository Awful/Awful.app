//  AwfulOldTableViewController.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulOldTableViewController.h"
#import "AwfulHTTPClient.h"
#import <SVPullToRefresh/UIScrollView+SVInfiniteScrolling.h>

@interface AwfulOldTableViewController ()

@property (nonatomic, getter=isObserving) BOOL observing;

@end

@implementation AwfulOldTableViewController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    if ([self canPullToRefresh]) {
        self.refreshControl = [UIRefreshControl new];
        [self.refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    }
    if ([self canPullForNextPage]) {
        __weak __typeof__(self) weakSelf = self;
        [self.tableView addInfiniteScrollingWithActionHandler:^{
            __typeof__(self) self = weakSelf;
            [self nextPage];
        }];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self refreshIfNeededOnAppear];
    [self startObservingApplicationDidBecomeActive];
}

- (void)becameActive
{
    if ([AwfulHTTPClient client].reachable) [self refreshIfNeededOnAppear];
}

- (void)refreshIfNeededOnAppear
{
    if ([self refreshOnAppear]) {
        [self refresh];
    }
}

- (void)startObservingApplicationDidBecomeActive
{
    if (self.observing) return;
    self.observing = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(becameActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self stopObservingApplicationDidBecomeActive];
    [super viewWillDisappear:animated];
}

- (void)stopObservingApplicationDidBecomeActive
{
    if (!self.observing) return;
    self.observing = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIApplicationDidBecomeActiveNotification
                                                  object:nil];
}

- (void)refresh
{
    self.refreshing = YES;
}

- (void)nextPage
{
    self.refreshing = YES;
}

- (void)stop
{
    self.refreshing = NO;
}

- (void)setRefreshing:(BOOL)refreshing
{
    if (_refreshing == refreshing) return;
    _refreshing = refreshing;
    if (refreshing) {
        [self.refreshControl beginRefreshing];
    } else {
        [self.refreshControl endRefreshing];
        if ([self canPullForNextPage]) [self.tableView.infiniteScrollingView stopAnimating];
    }
}

- (BOOL)canPullToRefresh
{
    return YES;
}

- (BOOL)canPullForNextPage
{
    return NO;
}

- (BOOL)refreshOnAppear
{
    return NO;
}

- (void)configureCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath *)indexPath
{
    [self doesNotRecognizeSelector:_cmd];
}

@end
