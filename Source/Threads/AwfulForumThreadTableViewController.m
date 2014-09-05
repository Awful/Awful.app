//  AwfulForumThreadTableViewController.m
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulForumThreadTableViewController.h"
#import "AwfulActionSheet.h"
#import "AwfulAlertView.h"
#import "AwfulAppDelegate.h"
#import "AwfulForumsClient.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulLoginController.h"
#import "AwfulModels.h"
#import "AwfulNewThreadViewController.h"
#import "AwfulPostsViewController.h"
#import "AwfulProfileViewController.h"
#import "AwfulRefreshMinder.h"
#import "AwfulSettings.h"
#import "AwfulThreadCell.h"
#import "AwfulThreadTagLoader.h"
#import "AwfulThreadTagPickerController.h"
#import <SVPullToRefresh/SVPullToRefresh.h>

@interface AwfulForumThreadTableViewController () <AwfulComposeTextViewControllerDelegate, AwfulThreadTagPickerControllerDelegate, UIViewControllerRestoration>

@property (strong, nonatomic) UIBarButtonItem *newThreadButtonItem;
@property (strong, nonatomic) UIButton *filterButton;
@property (strong, nonatomic) AwfulThreadTag *filterThreadTag;
@property (strong, nonatomic) AwfulThreadTagPickerController *threadTagPicker;

@end

@implementation AwfulForumThreadTableViewController
{
    NSInteger _mostRecentlyLoadedPage;
    AwfulNewThreadViewController *_newThreadViewController;
    BOOL _justLoaded;
}

- (id)initWithForum:(AwfulForum *)forum
{
    self = [super initWithNibName:nil bundle:nil];
    if (!self) return nil;
    
    _forum = forum;
    self.title = _forum.name;
    self.navigationItem.backBarButtonItem = [UIBarButtonItem awful_emptyBackBarButtonItem];
    self.newThreadButtonItem.enabled = forum.lastRefresh && forum.canPost;
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
    _newThreadViewController = [[AwfulNewThreadViewController alloc] initWithForum:self.forum];
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
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:AwfulThread.entityName];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"hideFromList == NO AND forum == %@", self.forum];
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
            [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
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

#pragma mark - AwfulComposeTextViewControllerDelegate

- (void)composeTextViewController:(AwfulNewThreadViewController *)newThreadViewController
didFinishWithSuccessfulSubmission:(BOOL)success
                  shouldKeepDraft:(BOOL)keepDraft
{
    [self dismissViewControllerAnimated:YES completion:^{
        if (success) {
            AwfulThread *thread = newThreadViewController.thread;
            AwfulPostsViewController *postsViewController = [[AwfulPostsViewController alloc] initWithThread:thread];
            postsViewController.restorationIdentifier = @"AwfulPostsViewController";
            [postsViewController loadPage:1 updatingCache:YES];
            [self showPostsViewController:postsViewController];
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
        [self.forum.threadTags enumerateObjectsUsingBlock:^(AwfulThreadTag *threadTag, NSUInteger i, BOOL *stop) {
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
    AwfulForum *forum = [AwfulForum fetchOrInsertForumInManagedObjectContext:managedObjectContext withID:[coder decodeObjectForKey:ForumIDKey]];
    AwfulForumThreadTableViewController *threadTableViewController = [[self alloc] initWithForum:forum];
    threadTableViewController.restorationIdentifier = identifierComponents.lastObject;
    threadTableViewController.restorationClass = self;
    NSError *error;
    if (![managedObjectContext save:&error]) {
        NSLog(@"%s error saving managed object context: %@", __PRETTY_FUNCTION__, error);
    }
    return threadTableViewController;
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeObject:self.forum.forumID forKey:ForumIDKey];
    [coder encodeObject:_newThreadViewController forKey:NewThreadViewControllerKey];
    [coder encodeObject:self.filterThreadTag.threadTagID forKey:FilterThreadTagIDKey];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];
    _newThreadViewController = [coder decodeObjectForKey:NewThreadViewControllerKey];
    _newThreadViewController.delegate = self;
    NSString *filterThreadTagID = [coder decodeObjectForKey:FilterThreadTagIDKey];
    if (filterThreadTagID) {
        self.filterThreadTag = [AwfulThreadTag fetchArbitraryInManagedObjectContext:self.forum.managedObjectContext
                                                            matchingPredicateFormat:@"threadTagID = %@", filterThreadTagID];
        [self updateFilterButtonText];
    }
}

static NSString * const ForumIDKey = @"AwfulForumID";
static NSString * const NewThreadViewControllerKey = @"AwfulNewThreadViewController";
static NSString * const FilterThreadTagIDKey = @"AwfulFilterThreadTagID";

@end
