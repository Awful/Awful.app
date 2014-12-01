//  ThreadListViewController.m
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "ThreadListViewController.h"
#import "AwfulAppDelegate.h"
#import "AwfulForumsClient.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulRefreshMinder.h"
#import "AwfulSettings.h"
#import "AwfulThreadTagLoader.h"
#import "AwfulThreadTagPickerController.h"
#import "PostsPageViewController.h"
#import <SVPullToRefresh/SVPullToRefresh.h>
#import "ThreadComposeViewController.h"
#import "Awful-Swift.h"

@interface ThreadListViewController () <AwfulComposeTextViewControllerDelegate, AwfulThreadTagPickerControllerDelegate, UIViewControllerRestoration>

@property (strong, nonatomic) UIBarButtonItem *newThreadButtonItem;
@property (strong, nonatomic) UIButton *filterButton;
@property (strong, nonatomic) ThreadTag *filterThreadTag;
@property (strong, nonatomic) AwfulThreadTagPickerController *threadTagPicker;

@end

@implementation ThreadListViewController
{
    NSInteger _mostRecentlyLoadedPage;
    ThreadComposeViewController *_newThreadViewController;
    BOOL _justLoaded;
}

- (instancetype)initWithForum:(Forum *)forum
{
    if ((self = [super initWithNibName:nil bundle:nil])) {
        _forum = forum;
        self.title = _forum.name;
        self.navigationItem.backBarButtonItem = [UIBarButtonItem awful_emptyBackBarButtonItem];
        self.newThreadButtonItem.enabled = forum.lastRefresh && forum.canPost;
        self.navigationItem.rightBarButtonItem = self.newThreadButtonItem;
    }
    return self;
}

- (UIBarButtonItem *)newThreadButtonItem
{
    if (_newThreadButtonItem) return _newThreadButtonItem;
    _newThreadButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose
                                                                         target:self
                                                                         action:@selector(didTapNewThreadButtonItem)];
    _newThreadButtonItem.accessibilityLabel = @"New thread";
    return _newThreadButtonItem;
}

- (void)didTapNewThreadButtonItem
{
    _newThreadViewController = [[ThreadComposeViewController alloc] initWithForum:self.forum];
    _newThreadViewController.restorationIdentifier = @"New thread composition";
    _newThreadViewController.delegate = self;
    [self presentViewController:[_newThreadViewController enclosingNavigationController] animated:YES completion:nil];
}

- (void)updateFilter
{
    if ([self isViewLoaded]) {
        self.threadDataSource.fetchedResultsController = [self createFetchedResultsController];
    }
}

static NSString * const kFilterThreadsTitle = @"Filter Threads";

- (AwfulThreadTagPickerController *)threadTagPicker
{
    if (_threadTagPicker) return _threadTagPicker;
    NSMutableArray *imageNames = [NSMutableArray arrayWithObject:AwfulThreadTagLoaderNoFilterImageName];
    [imageNames addObjectsFromArray:[self.forum.threadTags.array valueForKey:@"imageName"]];
    _threadTagPicker = [[AwfulThreadTagPickerController alloc] initWithImageNames:imageNames secondaryImageNames:nil];
    _threadTagPicker.delegate = self;
    _threadTagPicker.title = kFilterThreadsTitle;
    _threadTagPicker.navigationItem.leftBarButtonItem = _threadTagPicker.cancelButtonItem;
    return _threadTagPicker;
}

- (NSFetchedResultsController *)createFetchedResultsController
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:Thread.entityName];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"hideFromThreadList == NO AND forum == %@", self.forum];
    if (self.filterThreadTag) {
        NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"threadTag == %@", self.filterThreadTag];
        fetchRequest.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[ fetchRequest.predicate, filterPredicate ]];
    }
    fetchRequest.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"stickyIndex" ascending:YES],
                                 [NSSortDescriptor sortDescriptorWithKey:@"lastPostDate" ascending:NO] ];
    fetchRequest.fetchBatchSize = 20;
    return [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                               managedObjectContext:self.forum.managedObjectContext
                                                 sectionNameKeyPath:nil
                                                          cacheName:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.threadDataSource.fetchedResultsController = [self createFetchedResultsController];
    self.refreshControl = [UIRefreshControl new];
    [self.refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    __weak __typeof__(self) weakSelf = self;
    [self.tableView addInfiniteScrollingWithActionHandler:^{
        __typeof__(self) self = weakSelf;
        [self loadPage:self->_mostRecentlyLoadedPage + 1];
    }];
    self.tableView.tableHeaderView = self.filterButton;
    _justLoaded = YES;
}

- (UIButton *)filterButton
{
    if (_filterButton) return _filterButton;
    _filterButton = [UIButton buttonWithType:UIButtonTypeSystem];
    CGRect frame = _filterButton.frame;
    frame.size.height = _filterButton.intrinsicContentSize.height + 8;
    _filterButton.frame = frame;
    [_filterButton addTarget:self action:@selector(showFilterPicker:) forControlEvents:UIControlEventTouchUpInside];
    [self updateFilterButtonText];
    return _filterButton;
}

- (void)showFilterPicker:(UIButton *)button
{
    NSString *selectedTagImageName = self.filterThreadTag.imageName ?: AwfulThreadTagLoaderNoFilterImageName;
    [self.threadTagPicker selectImageName:selectedTagImageName];
    [self.threadTagPicker presentFromView:button];
}

- (void)updateFilterButtonText
{
    if (self.filterThreadTag) {
        [self.filterButton setTitle:@"Change filter" forState:UIControlStateNormal];
    } else {
        [self.filterButton setTitle:@"Filter by tag" forState:UIControlStateNormal];
    }
}

- (void)themeDidChange
{
    [super themeDidChange];
    self.filterButton.tintColor = self.theme[@"tintColor"];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (_justLoaded) {
        [self.tableView setContentOffset:CGPointMake(0, CGRectGetHeight(self.tableView.tableHeaderView.frame)) animated:NO];
        _justLoaded = NO;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    NSFetchedResultsController *fetchedResultsController = self.threadDataSource.fetchedResultsController;
    self.tableView.showsInfiniteScrolling = fetchedResultsController.fetchedObjects.count > 0;
    [self refreshIfNecessary];
    self.userActivity = [[NSUserActivity alloc] initWithActivityType:Handoff.ActivityTypeListingThreads];
    self.userActivity.needsSave = YES;
}

- (void)refreshIfNecessary
{
    if (![AwfulForumsClient client].reachable) return;
    
    NSFetchedResultsController *fetchedResultsController = self.threadDataSource.fetchedResultsController;
    if (fetchedResultsController.fetchedObjects.count == 0 ||
        (self.filterThreadTag && [[AwfulRefreshMinder minder] shouldRefreshFilteredForum:self.forum]) ||
        (!self.filterThreadTag && [[AwfulRefreshMinder minder] shouldRefreshForum:self.forum])) {
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
    [[AwfulForumsClient client] listThreadsInForum:self.forum withThreadTag:self.filterThreadTag onPage:page andThen:^(NSError *error, NSArray *threads) {
        __typeof__(self) self = weakSelf;
        if (error) {
            [self presentViewController:[UIAlertController alertWithNetworkError:error] animated:YES completion:nil];
        } else {
            if (page == 1) {
                self.tableView.showsInfiniteScrolling = YES;
            }
            if (self.filterThreadTag) {
                [[AwfulRefreshMinder minder] didFinishRefreshingFilteredForum:self.forum];
            } else {
                [[AwfulRefreshMinder minder] didFinishRefreshingForum:self.forum];
            }
            self.newThreadButtonItem.enabled = self.forum.canPost;
        }
        _mostRecentlyLoadedPage = page;
        [self.refreshControl endRefreshing];
        [self.tableView.infiniteScrollingView stopAnimating];
        self.title = self.forum.name;
    }];
}

- (void)updateUserActivityState:(NSUserActivity *)activity
{
    activity.title = self.forum.name;
    [activity addUserInfoEntriesFromDictionary:@{Handoff.InfoForumIDKey: self.forum.forumID}];
    activity.webpageURL = [NSURL URLWithString:[NSString stringWithFormat:@"/forumdisplay.php?forumid=%@", self.forum.forumID]
                                 relativeToURL:[AwfulForumsClient client].baseURL];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    self.userActivity = nil;
}

#pragma mark - AwfulThreadTableViewController

- (AwfulTheme *)theme
{
    return [AwfulTheme currentThemeForForum:self.forum];
}

#pragma mark - AwfulFetchedResultsControllerDataSource

- (void)configureCell:(ThreadCell *)cell withObject:(Thread *)thread
{
    [super configureCell:cell withObject:thread];
    cell.stickyImageView.hidden = !thread.sticky;
}

#pragma mark - AwfulComposeTextViewControllerDelegate

- (void)composeTextViewController:(ThreadComposeViewController *)newThreadViewController
didFinishWithSuccessfulSubmission:(BOOL)success
                  shouldKeepDraft:(BOOL)keepDraft
{
    [self dismissViewControllerAnimated:YES completion:^{
        if (success) {
            Thread *thread = newThreadViewController.thread;
            PostsPageViewController *postsViewController = [[PostsPageViewController alloc] initWithThread:thread];
            postsViewController.restorationIdentifier = @"AwfulPostsViewController";
            [postsViewController loadPage:1 updatingCache:YES];
            [self showDetailViewController:postsViewController sender:self];
        }
        if (!keepDraft) {
            _newThreadViewController = nil;
        }
    }];
}

#pragma mark - AwfulThreadTagPickerControllerDelegate

- (void)threadTagPicker:(AwfulThreadTagPickerController *)picker didSelectImageName:(NSString *)imageName
{
    if ([imageName isEqualToString:AwfulThreadTagLoaderNoFilterImageName]) {
        self.filterThreadTag = nil;
    } else {
        [self.forum.threadTags enumerateObjectsUsingBlock:^(ThreadTag *threadTag, NSUInteger i, BOOL *stop) {
            if ([threadTag.imageName isEqualToString:imageName]) {
                self.filterThreadTag = threadTag;
                *stop = YES;
            }
        }];
    }
    
    [self updateFilterButtonText];
    [[AwfulRefreshMinder minder] forgetForum:self.forum];
    [self updateFilter];
    [self refresh];
    [picker dismiss];
}

#pragma mark - State preservation and restoration

+ (UIViewController *)viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    NSManagedObjectContext *managedObjectContext = [AwfulAppDelegate instance].managedObjectContext;
    ForumKey *forumKey = [coder decodeObjectForKey:ForumKeyKey];
    if (!forumKey) {
        // AwfulObjectKey was introduced in Awful 3.2.
        NSString *forumID = [coder decodeObjectForKey:obsolete_ForumIDKey];
        forumKey = [[ForumKey alloc] initWithForumID:forumID];
    }
    Forum *forum = [Forum objectForKey:forumKey inManagedObjectContext:managedObjectContext];
    ThreadListViewController *threadTableViewController = [[self alloc] initWithForum:forum];
    threadTableViewController.restorationIdentifier = identifierComponents.lastObject;
    threadTableViewController.restorationClass = self;
    return threadTableViewController;
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeObject:self.forum.objectKey forKey:ForumKeyKey];
    [coder encodeObject:_newThreadViewController forKey:NewThreadViewControllerKey];
    [coder encodeObject:self.filterThreadTag.objectKey forKey:FilterThreadTagKeyKey];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];
    _newThreadViewController = [coder decodeObjectForKey:NewThreadViewControllerKey];
    _newThreadViewController.delegate = self;
    ThreadTagKey *filterTagKey = [coder decodeObjectForKey:FilterThreadTagKeyKey];
    if (!filterTagKey) {
        // AwfulObjectKey was introduced in Awful 3.2.
        NSString *filterThreadTagID = [coder decodeObjectForKey:obsolete_FilterThreadTagIDKey];
        if (filterThreadTagID) {
            filterTagKey = [[ThreadTagKey alloc] initWithImageName:nil threadTagID:filterThreadTagID];
        }
    }
    if (filterTagKey) {
        self.filterThreadTag = [ThreadTag objectForKey:filterTagKey inManagedObjectContext:self.forum.managedObjectContext];
    }
    [self updateFilterButtonText];
}

static NSString * const obsolete_ForumIDKey = @"AwfulForumID";
static NSString * const ForumKeyKey = @"ForumKey";
static NSString * const NewThreadViewControllerKey = @"AwfulNewThreadViewController";
static NSString * const FilterThreadTagKeyKey = @"FilterThreadTagKey";
static NSString * const obsolete_FilterThreadTagIDKey = @"AwfulFilterThreadTagID";

@end
