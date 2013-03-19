//
//  AwfulTableViewController.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulTableViewController.h"
#import "AwfulHTTPClient.h"
#import "AwfulTheme.h"
#import "SVPullToRefresh.h"

@interface AwfulTableViewController ()

@property (nonatomic, getter=isObserving) BOOL observing;

@end

@implementation AwfulTableViewController

- (void)dealloc
{
    [self stopObservingApplicationDidBecomeActive];
}

- (void)themeChanged:(NSNotification *)note
{
    if (![self isViewLoaded]) return;
    [self.tableView reloadData];
    [self retheme];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self retheme];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    __weak AwfulTableViewController *blockSelf = self;
    if ([self canPullToRefresh]) {
        [self.tableView addPullToRefreshWithActionHandler:^{
            [blockSelf refresh];
        }];
    }
    if ([self canPullForNextPage]) {
        [self.tableView addInfiniteScrollingWithActionHandler:^{
            [blockSelf nextPage];
        }];
    }
    [self refreshIfNeededOnAppear];
    [self startObservingApplicationDidBecomeActive];
}

- (void)becameActive
{
    if ([AwfulHTTPClient client].reachable) [self refreshIfNeededOnAppear];
}

- (void)refreshIfNeededOnAppear
{
    if (![self refreshOnAppear]) return;
    if ([self canPullToRefresh]) {
        [self.tableView.pullToRefreshView triggerRefresh];
    } else {
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
        if ([self canPullToRefresh]) [self.tableView.pullToRefreshView startAnimating];
    } else {
        if ([self canPullToRefresh]) [self.tableView.pullToRefreshView stopAnimating];
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

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    }
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

- (void)configureCell:(UITableViewCell*)cell atIndexPath:(NSIndexPath *)indexPath
{
    [NSException raise:NSInternalInconsistencyException
                format:@"Subclasses must implement %@", NSStringFromSelector(_cmd)];
}

#pragma mark - AwfulThemingViewController

- (void)retheme
{
    UIActivityIndicatorViewStyle style = [AwfulTheme currentTheme].activityIndicatorViewStyle;
    if ([self canPullToRefresh]) {
        self.tableView.pullToRefreshView.activityIndicatorViewStyle = style;
    }
    if ([self canPullForNextPage]) {
        self.tableView.infiniteScrollingView.activityIndicatorViewStyle = style;
    }
    [self.tableView reloadData];
}

@end
