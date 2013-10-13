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
#import "NSString+CollapseWhitespace.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import <SVPullToRefresh/SVPullToRefresh.h>
#import "UITableView+HideStuff.h"
#import "UIViewController+NavigationEnclosure.h"

@interface AwfulForumThreadTableViewController () <AwfulFetchedResultsControllerDataSourceDelegate, AwfulThreadComposeViewControllerDelegate, UIViewControllerRestoration>

@property (strong, nonatomic) UIBarButtonItem *newThreadButtonItem;
@property (strong, nonatomic) UIBarButtonItem *abbreviatedBackButtonItem;
@property (strong, nonatomic) AwfulThreadComposeViewController *composeViewController;

@end

@implementation AwfulForumThreadTableViewController
{
    AwfulFetchedResultsControllerDataSource *_threadDataSource;
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

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    return [self initWithForum:nil];
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

- (void)loadView
{
    [super loadView];
    [self.tableView registerClass:[AwfulThreadCell class] forCellReuseIdentifier:ThreadCellIdentifier];
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 60, 0, 0);
    [self.tableView awful_hideExtraneousSeparators];
}

static NSString * const ThreadCellIdentifier = @"Thread Cell";

- (void)viewDidLoad
{
    [super viewDidLoad];
    _threadDataSource = [[AwfulFetchedResultsControllerDataSource alloc] initWithTableView:self.tableView
                                                                           reuseIdentifier:ThreadCellIdentifier];
    _threadDataSource.delegate = self;
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:AwfulThread.entityName];
    request.predicate = [NSPredicate predicateWithFormat:@"hideFromList == NO AND forum == %@", self.forum];
    request.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"stickyIndex" ascending:YES],
                                 [NSSortDescriptor sortDescriptorWithKey:@"lastPostDate" ascending:NO] ];
    NSManagedObjectContext *context = self.forum.managedObjectContext;
    _threadDataSource.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                                                     managedObjectContext:context
                                                                                       sectionNameKeyPath:nil
                                                                                                cacheName:nil];
    
    UIRefreshControl *refreshControl = [UIRefreshControl new];
    [refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refreshControl;
    
    __weak __typeof__(self) weakSelf = self;
    [self.tableView addInfiniteScrollingWithActionHandler:^{
        __typeof__(self) self = weakSelf;
        [self loadPage:self->_mostRecentlyLoadedPage + 1];
    }];
}

- (void)themeDidChange
{
	[super themeDidChange];
	self.view.backgroundColor = [AwfulTheme currentThemeForForum:self.forum][@"backgroundColor"];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if ([self refreshOnAppear]) {
        [self refresh];
    }
}

- (BOOL)refreshOnAppear
{
    if (![AwfulHTTPClient client].reachable) return NO;
    if (!self.forum.lastRefresh) return YES;
    if ([_threadDataSource.fetchedResultsController.fetchedObjects count] == 0) return YES;
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
            [self.tableView beginUpdates];
            if (page == 1) {
                NSMutableSet *threadsToHide = [self.forum.threads mutableCopy];
                for (AwfulThread *thread in threads) {
                    [threadsToHide removeObject:thread];
                }
                [threadsToHide setValue:@YES forKey:@"hideFromList"];
            }
            [threads setValue:@NO forKey:@"hideFromList"];
            self.forum.lastRefresh = [NSDate date];
            NSError *error;
            BOOL ok = [self.forum.managedObjectContext save:&error];
            if (!ok) {
                NSLog(@"%s error saving managed object context while loading %@ page %tu: %@",
                      __PRETTY_FUNCTION__, self.forum.name, page, error);
            }
            [self.tableView endUpdates];
        }
        _mostRecentlyLoadedPage = page;
        [self.refreshControl endRefreshing];
        [self.tableView.infiniteScrollingView stopAnimating];
    }];
}


- (void)doneWithProfile
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)displayPage:(AwfulPostsViewController *)page
{
    if (self.expandingSplitViewController) {
        UINavigationController *nav = [page enclosingNavigationController];
        nav.restorationIdentifier = @"Navigation";
        self.expandingSplitViewController.detailViewController = nav;
    } else {
        [self.navigationController pushViewController:page animated:YES];
    }
}

#pragma mark - AwfulFetchedResultsControllerDataSource

- (void)configureCell:(AwfulThreadCell *)cell withObject:(AwfulThread *)thread
{
    UILongPressGestureRecognizer *longPress = [UILongPressGestureRecognizer new];
    [longPress addTarget:self action:@selector(showThreadActions:)];
    [cell addGestureRecognizer:longPress];
    
    // It's possible to pick the same tag for the first and second icons in e.g. SA Mart.
    // Since it'd look ugly to show the e.g. "Selling" banner for each tag image, we just use
    // the empty thread tag for anyone lame enough to pick the same tag twice.
    UIImage *emptyTag = [UIImage imageNamed:@"empty-thread-tag"];
    if ([thread.firstIconName isEqualToString:thread.secondIconName]) {
        cell.tagAndRatingView.threadTag = emptyTag;
    } else {
        UIImage *threadTag = [[AwfulThreadTags sharedThreadTags] threadTagNamed:thread.firstIconName];
        cell.tagAndRatingView.threadTag = threadTag ?: emptyTag;
    }
    
    cell.tagAndRatingView.secondaryThreadTagBadge.hidden = NO;
    if ([thread.secondIconName isEqualToString:@"icon-37-selling.png"]) {
        cell.tagAndRatingView.secondaryThreadTagBadge.text = @"S";
    } else if ([thread.secondIconName isEqualToString:@"icon-46-trading.png"]) {
        cell.tagAndRatingView.secondaryThreadTagBadge.text = @"T";
    } else if ([thread.secondIconName isEqualToString:@"icon-38-buying.png"]) {
        cell.tagAndRatingView.secondaryThreadTagBadge.text = @"B";
    } else if ([thread.secondIconName isEqualToString:@"icon-52-trading.png"]) {
        cell.tagAndRatingView.secondaryThreadTagBadge.text = @"A";
    } else if ([thread.secondIconName isEqualToString:@"ama.png"]) {
        cell.tagAndRatingView.secondaryThreadTagBadge.text = @"A";
    } else if ([thread.secondIconName isEqualToString:@"tma.png"]) {
        cell.tagAndRatingView.secondaryThreadTagBadge.text = @"T";
    } else {
        cell.tagAndRatingView.secondaryThreadTagBadge.hidden = YES;
    }
    
    if (thread.sticky) {
        cell.stickyImageView.image = [UIImage imageNamed:@"sticky"];
    } else {
        cell.stickyImageView.image = nil;
    }
    // Hardcode Film Dump to never show ratings; its thread tags are the ratings.
    if ([thread.forum.forumID isEqualToString:@"133"]) {
        cell.tagAndRatingView.ratingImage = nil;
    } else {
        NSInteger rating = lroundf(thread.rating.floatValue);
        if (rating <= 0) {
            cell.tagAndRatingView.ratingImage = nil;
        } else {
            if (rating < 1) {
                rating = 1;
            } else if (rating > 5) {
                rating = 5;
            }
            cell.tagAndRatingView.ratingImage = [UIImage imageNamed:[NSString stringWithFormat:@"rating%zd", rating]];
        }
    }
    cell.textLabel.text = [thread.title stringByCollapsingWhitespace];
    if (thread.sticky || !thread.closed) {
        cell.tagAndRatingView.alpha = 1;
        cell.textLabel.enabled = YES;
    } else {
        cell.tagAndRatingView.alpha = 0.5;
        cell.textLabel.enabled = NO;
    }
    cell.numberOfPagesLabel.text = @(thread.numberOfPages).stringValue;
    if (thread.beenSeen) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Killed by %@", thread.lastPostAuthorName];
    } else {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Posted by %@", thread.author.username];
    }
    NSInteger unreadPosts = thread.totalReplies + 1 - thread.seenPosts;
    cell.badgeLabel.text = @(unreadPosts).stringValue;
    [self themeCell:cell forObject:thread];
}

- (void)showThreadActions:(UILongPressGestureRecognizer *)longPress
{
    if (longPress.state != UIGestureRecognizerStateBegan) return;
    UITableViewCell *cell = (UITableViewCell *)longPress.view;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    AwfulThread *thread = [_threadDataSource.fetchedResultsController objectAtIndexPath:indexPath];
    [self showThreadActionsForThread:thread];
}

- (void)showThreadActionsForThread:(AwfulThread *)thread
{
    AwfulIconActionSheet *sheet = [AwfulIconActionSheet new];
    sheet.title = [thread.title stringByCollapsingWhitespace];
    [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeJumpToFirstPage action:^{
        AwfulPostsViewController *page = [[AwfulPostsViewController alloc] initWithThread:thread];
        page.restorationIdentifier = @"AwfulPostsViewController";
        [self displayPage:page];
        page.page = 1;
    }]];
    [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeJumpToLastPage action:^{
        AwfulPostsViewController *page = [[AwfulPostsViewController alloc] initWithThread:thread];
        page.restorationIdentifier = @"AwfulPostsViewController";
        [self displayPage:page];
        page.page = AwfulThreadPageLast;
    }]];
    AwfulIconActionItemType bookmarkItemType;
    if (thread.bookmarked) {
        bookmarkItemType = AwfulIconActionItemTypeRemoveBookmark;
    } else {
        bookmarkItemType = AwfulIconActionItemTypeAddBookmark;
    }
    [sheet addItem:[AwfulIconActionItem itemWithType:bookmarkItemType action:^{
        [[AwfulHTTPClient client] setThreadWithID:thread.threadID
                                     isBookmarked:!thread.bookmarked
                                          andThen:^(NSError *error)
         {
             if (error) {
                 [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
             } else {
                 NSString *status = @"Removed Bookmark";
                 if (thread.bookmarked) {
                     status = @"Added Bookmark";
                 }
                 [SVProgressHUD showSuccessWithStatus:status];
             }
         }];
    }]];
    if ([thread.author.userID length] > 0) {
        AwfulIconActionItem *profileItem = [AwfulIconActionItem itemWithType:AwfulIconActionItemTypeUserProfile action:^{
            AwfulProfileViewController *profile = [[AwfulProfileViewController alloc] initWithUser:thread.author];
            profile.hidesBottomBarWhenPushed = YES;
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                UIBarButtonItem *done;
                done = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                     target:self
                                                                     action:@selector(doneWithProfile)];
                profile.navigationItem.leftBarButtonItem = done;
                [self presentViewController:[profile enclosingNavigationController]
                                   animated:YES completion:nil];
            } else {
                [self.navigationController pushViewController:profile animated:YES];
            }
        }];
        profileItem.title = @"View OP's Profile";
        [sheet addItem:profileItem];
    }
    [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeCopyURL action:^{
        NSString *url = [NSString stringWithFormat:@"http://forums.somethingawful.com/"
                         "showthread.php?threadid=%@", thread.threadID];
        [AwfulSettings settings].lastOfferedPasteboardURL = url;
        [UIPasteboard generalPasteboard].items = @[ @{
                                                        (id)kUTTypeURL: [NSURL URLWithString:url],
                                                        (id)kUTTypePlainText: url
                                                        }];
    }]];
    if (thread.beenSeen) {
        [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeMarkAsUnread action:^{
            if (!thread.threadID) {
                return NSLog(@"thread %@ is missing a thread ID; cannot mark unseen", thread.title);
            }
            [[AwfulHTTPClient client] forgetReadPostsInThreadWithID:thread.threadID andThen:^(NSError *error) {
                if (error) {
                    [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
                } else {
                    thread.seenPosts = 0;
                    NSError *error;
                    BOOL ok = [thread.managedObjectContext save:&error];
                    if (!ok) {
                        NSLog(@"%s error saving thread %@ marked unread: %@", __PRETTY_FUNCTION__, thread.threadID, error);
                    }
                }
            }];
        }]];
    }
    NSIndexPath *indexPath = [_threadDataSource.fetchedResultsController indexPathForObject:thread];
    // The cell can be nil if it's invisible or out of range. The table view is an acceptable fallback.
    UIView *view = [self.tableView cellForRowAtIndexPath:indexPath] ?: self.tableView;
    [sheet showFromRect:view.frame inView:self.tableView animated:YES];
}

- (void)themeCell:(AwfulThreadCell *)cell forObject:(AwfulThread *)thread
{
    AwfulTheme *theme = [AwfulTheme currentThemeForForum:self.forum];
    cell.backgroundColor = theme[@"listBackgroundColor"];
    cell.textLabel.textColor = theme[@"listTextColor"];
    switch (thread.starCategory) {
        case AwfulStarCategoryOrange: cell.badgeLabel.textColor = theme[@"unreadBadgeOrangeColor"]; break;
        case AwfulStarCategoryRed: cell.badgeLabel.textColor = theme[@"unreadBadgeRedColor"]; break;
        case AwfulStarCategoryYellow: cell.badgeLabel.textColor = theme[@"unreadBadgeYellowColor"]; break;
        default: cell.badgeLabel.textColor = theme[@"tintColor"]; break;
    }
    if ([thread.secondIconName isEqualToString:@"icon-37-selling.png"]) {
        cell.tagAndRatingView.secondaryThreadTagBadge.backgroundColor = theme[@"sellingBadgeColor"];
    } else if ([thread.secondIconName isEqualToString:@"icon-46-trading.png"]) {
        cell.tagAndRatingView.secondaryThreadTagBadge.backgroundColor = theme[@"tradingBadgeColor"];
    } else if ([thread.secondIconName isEqualToString:@"icon-38-buying.png"]) {
        cell.tagAndRatingView.secondaryThreadTagBadge.backgroundColor = theme[@"buyingBadgeColor"];
    } else if ([thread.secondIconName isEqualToString:@"icon-52-trading.png"]) {
        cell.tagAndRatingView.secondaryThreadTagBadge.backgroundColor = theme[@"auctionBadgeColor"];
    } else if ([thread.secondIconName isEqualToString:@"ama.png"]) {
        cell.tagAndRatingView.secondaryThreadTagBadge.backgroundColor = theme[@"askBadgeColor"];
    } else if ([thread.secondIconName isEqualToString:@"tma.png"]) {
        cell.tagAndRatingView.secondaryThreadTagBadge.backgroundColor = theme[@"tellBadgeColor"];
    }
}

- (void)themeCell:(AwfulThreadCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    [super themeCell:cell atIndexPath:indexPath];
    AwfulThread *thread = [_threadDataSource.fetchedResultsController objectAtIndexPath:indexPath];
    [self themeCell:cell forObject:thread];
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 75;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
    AwfulThread *thread = [_threadDataSource.fetchedResultsController objectAtIndexPath:indexPath];
    AwfulPostsViewController *page = [[AwfulPostsViewController alloc] initWithThread:thread];
    page.restorationIdentifier = @"AwfulPostsViewController";
    // For an unread thread, the Forums will interpret "next unread page" to mean "last page",
    // which is not very helpful.
    page.page = thread.beenSeen ? AwfulThreadPageNextUnread : 1;
    [self displayPage:page];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - AwfulThreadComposeViewControllerDelegate

- (void)threadComposeController:(AwfulThreadComposeViewController *)controller
            didPostThreadWithID:(NSString *)threadID
{
    self.composeViewController = nil;
    [self dismissViewControllerAnimated:YES completion:nil];
    AwfulThread *thread = [AwfulThread firstOrNewThreadWithThreadID:threadID
                                             inManagedObjectContext:self.forum.managedObjectContext];
    AwfulPostsViewController *page = [[AwfulPostsViewController alloc] initWithThread:thread];
    page.restorationIdentifier = @"AwfulPostsViewController";
    page.page = 1;
    [self displayPage:page];
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
