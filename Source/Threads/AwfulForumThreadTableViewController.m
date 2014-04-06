//  AwfulForumThreadTableViewController.m
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulForumThreadTableViewController.h"
#import "AwfulActionSheet.h"
#import "AwfulAlertView.h"
#import "AwfulAppDelegate.h"
#import "AwfulForumsClient.h"
#import "AwfulLoginController.h"
#import "AwfulModels.h"
#import "AwfulNewThreadViewController.h"
#import "AwfulPostsViewController.h"
#import "AwfulProfileViewController.h"
#import "AwfulRefreshMinder.h"
#import "AwfulSettings.h"
#import "AwfulThreadCell.h"
#import "AwfulThreadTagLoader.h"
#import "AwfulPostIconPickerController.h"
#import "AwfulUIKitAndFoundationCategories.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import <SVPullToRefresh/SVPullToRefresh.h>

@interface AwfulForumThreadTableViewController () <AwfulComposeTextViewControllerDelegate, AwfulPostIconPickerControllerDelegate, UIViewControllerRestoration>

@property (strong, nonatomic) UIBarButtonItem *newThreadButtonItem;
@property (strong, nonatomic) UIButton *filterButton;
@property (strong, nonatomic) AwfulThreadTag *filterThreadTag;
@property (strong, nonatomic) AwfulPostIconPickerController *postIconPicker;

@end

@implementation AwfulForumThreadTableViewController
{
    NSInteger _mostRecentlyLoadedPage;
    AwfulNewThreadViewController *_newThreadViewController;
    BOOL _justLoaded;
}

- (id)initWithForum:(AwfulForum *)forum
{
    if (!(self = [super initWithNibName:nil bundle:nil])) return nil;
    _forum = forum;
    self.title = _forum.abbreviatedName;
    self.navigationItem.backBarButtonItem = [UIBarButtonItem emptyBackBarButtonItem];
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

- (AwfulPostIconPickerController *)postIconPicker
{
    if (_postIconPicker) return _postIconPicker;
    _postIconPicker = [[AwfulPostIconPickerController alloc] initWithDelegate:self];
    _postIconPicker.title = @"Filter Threads";
    [_postIconPicker reloadData];
    return _postIconPicker;
}

- (NSFetchedResultsController *)createFetchedResultsController
{
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:AwfulThread.entityName];
    request.predicate = [NSPredicate predicateWithFormat:@"hideFromList == NO AND forum == %@", self.forum];
    if (self.filterThreadTag) {
        NSPredicate *filterPredicate = [NSPredicate predicateWithFormat:@"threadTag == %@", self.filterThreadTag];
        request.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[ request.predicate, filterPredicate ]];
    }
    request.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"stickyIndex" ascending:YES],
                                 [NSSortDescriptor sortDescriptorWithKey:@"lastPostDate" ascending:NO] ];
    return [[NSFetchedResultsController alloc] initWithFetchRequest:request
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
    if (self.filterThreadTag) {
        self.postIconPicker.selectedIndex = [self.forum.threadTags indexOfObject:self.filterThreadTag] + 1;
    } else {
        self.postIconPicker.selectedIndex = 0;
    }
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.postIconPicker showFromRect:button.bounds inView:button];
    } else {
        [self presentViewController:[self.postIconPicker enclosingNavigationController] animated:YES completion:nil];
    }
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
            postsViewController.page = 1;
            [self showPostsViewController:postsViewController];
        }
        if (!keepDraft) {
            _newThreadViewController = nil;
        }
    }];
}

#pragma mark - AwfulPostIconPickerControllerDelegate

- (NSInteger)numberOfIconsInPostIconPicker:(AwfulPostIconPickerController *)picker
{
    // +1 for empty thread tag (aka "no filter").
    return self.forum.threadTags.count + 1;
}

- (UIImage *)postIconPicker:(AwfulPostIconPickerController *)picker postIconAtIndex:(NSInteger)index
{
    if (index == 0) {
        return [[AwfulThreadTagLoader loader] emptyThreadTagImage];
    } else {
        AwfulThreadTag *threadTag = self.forum.threadTags[index - 1];
        return [[AwfulThreadTagLoader loader] imageNamed:threadTag.imageName];
    }
}

- (void)postIconPickerDidComplete:(AwfulPostIconPickerController *)picker
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) return;
    NSInteger index = picker.selectedIndex;
    if (index == 0 || index == NSNotFound) {
        self.filterThreadTag = nil;
    } else {
        self.filterThreadTag = self.forum.threadTags[index - 1];
    }
    [self refreshForFilterChange];
    [self.tableView setContentOffset:CGPointMake(0, CGRectGetHeight(self.tableView.tableHeaderView.frame)) animated:NO];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)postIconPickerDidCancel:(AwfulPostIconPickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)postIconPicker:(AwfulPostIconPickerController *)picker didSelectIconAtIndex:(NSInteger)index
{
    if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad) return;
    if (index == 0) {
        self.filterThreadTag = nil;
    } else {
        self.filterThreadTag = self.forum.threadTags[index - 1];
    }
    [self refreshForFilterChange];
}

- (void)refreshForFilterChange
{
    [self updateFilterButtonText];
    [[AwfulRefreshMinder minder] forgetForum:self.forum];
    [self updateFilter];
    [self refresh];
}

#pragma mark - State preservation and restoration

+ (UIViewController *)viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    AwfulForum *forum = [AwfulForum fetchOrInsertForumInManagedObjectContext:[AwfulAppDelegate instance].managedObjectContext
                                                                      withID:[coder decodeObjectForKey:ForumIDKey]];
    AwfulForumThreadTableViewController *threadTableViewController = [[self alloc] initWithForum:forum];
    threadTableViewController.restorationIdentifier = identifierComponents.lastObject;
    threadTableViewController.restorationClass = self;
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
