//
//  AwfulTableViewController.m
//  Awful
//
//  Created by Sean Berry on 2/29/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulTableViewController.h"
#import "AwfulHTTPClient.h"
#import "AwfulTheme.h"
#import "SVPullToRefresh.h"
#import "AwfulAppState.h"
#import "AwfulAppDelegate.h"

@interface AwfulTableViewController ()

@property (nonatomic, getter=isObserving) BOOL observing;
@property (nonatomic,readonly) CGFloat contentOffsetPercentage;
@property (nonatomic,readonly) NSIndexPath* screenIndexPath;
@end

@implementation AwfulTableViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    if (!(self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) return nil;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(themeChanged:)
                                                 name:AwfulThemeDidChangeNotification
                                               object:nil];
    
    return self;
}

- (void)dealloc
{
    [self stopObservingApplicationDidBecomeActive];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AwfulThemeDidChangeNotification
                                                  object:nil];
}

- (void)themeChanged:(NSNotification *)note
{
    if (![self isViewLoaded]) return;
    [self.tableView reloadData];
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
    [self retheme];
    [self refreshIfNeededOnAppear];
    [self startObservingApplicationDidBecomeActive];
    
    self.contentOffsetPercentage = [[AwfulAppState sharedAppState]
                                    scrollOffsetPercentageForScreen:self.awfulScreenURL];
    
    [[AwfulAppState sharedAppState] setScreenURL:self.awfulScreenURL
                                     atIndexPath:self.screenIndexPath];
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
    [self.networkOperation cancel];
    self.refreshing = NO;
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

- (void)retheme
{
    UIActivityIndicatorViewStyle style = [AwfulTheme currentTheme].activityIndicatorViewStyle;
    if ([self canPullToRefresh]) {
        self.tableView.pullToRefreshView.activityIndicatorViewStyle = style;
    }
    if ([self canPullForNextPage]) {
        self.tableView.infiniteScrollingView.activityIndicatorViewStyle = style;
    }
}

- (NSURL*)awfulScreenURL
{
    NSLog(@"subclass %@ does not override awfulScreenURL", [[self class] description]);
    return nil;
}

#pragma mark scroll delegate
-(void) scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
       [[AwfulAppState sharedAppState] setScrollOffsetPercentage:self.contentOffsetPercentage
                                                       forScreen:self.awfulScreenURL];
    });
}

- (CGFloat)contentOffsetPercentage
{
    CGFloat contentHeight = self.tableView.contentSize.height;
    CGFloat frameHeight = self.tableView.frame.size.height;
    CGFloat scrollMax = contentHeight - frameHeight;
    
    CGFloat scrollOffset = self.tableView.contentOffset.y;
    
    return ((scrollOffset / scrollMax) < 1)? (scrollOffset / scrollMax) : 1 ;
}

- (void)setContentOffsetPercentage:(CGFloat)contentOffsetPercentage
{
    CGFloat contentHeight = self.tableView.contentSize.height;
    CGFloat frameHeight = self.tableView.frame.size.height;
    CGFloat scrollMax = contentHeight - frameHeight;
    scrollMax = (scrollMax < 0)? 0 : scrollMax;
    
    CGFloat offset = contentOffsetPercentage * scrollMax;
    
    self.tableView.contentOffset = CGPointMake(0, offset);
}

- (NSIndexPath*)screenIndexPath
{
    return [[AwfulAppState sharedAppState] indexPathForViewController:self];
}


@end
