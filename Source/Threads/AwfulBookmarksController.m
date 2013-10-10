//  AwfulBookmarksController.m
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulBookmarksController.h"
#import "AwfulFetchedTableViewControllerSubclass.h"
#import "AwfulAlertView.h"
#import "AwfulExpandingSplitViewController.h"
#import "AwfulHTTPClient.h"
#import "AwfulIconActionSheet.h"
#import "AwfulModels.h"
#import "AwfulPostsViewController.h"
#import "AwfulProfileViewController.h"
#import "AwfulSettings.h"
#import "AwfulThreadCell.h"
#import "AwfulThreadTags.h"
#import "NSString+CollapseWhitespace.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import "UIScrollView+SVInfiniteScrolling.h"
#import "UIViewController+NavigationEnclosure.h"

@interface AwfulBookmarksController ()

@property (nonatomic) NSDate *lastRefreshDate;
@property (nonatomic) BOOL showBookmarkColors;
@property (nonatomic) NSMutableSet *cellsMissingThreadTags;
@property (assign, nonatomic) NSInteger currentPage;

@end

@implementation AwfulBookmarksController

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    if (!(self = [super initWithStyle:UITableViewStylePlain])) return nil;
    _managedObjectContext = managedObjectContext;
    _cellsMissingThreadTags = [NSMutableSet new];
    self.title = @"Bookmarks";
    self.tabBarItem.image = [UIImage imageNamed:@"bookmarks.png"];
    UIImage *portrait = [UIImage imageNamed:@"bookmarks.png"];
    UIImage *landscapePhone = [UIImage imageNamed:@"bookmarks-landscape.png"];
    UIBarButtonItem *marks = [[UIBarButtonItem alloc] initWithImage:portrait
                                                landscapeImagePhone:landscapePhone
                                                              style:UIBarButtonItemStylePlain
                                                             target:nil
                                                             action:NULL];
    self.navigationItem.backBarButtonItem = marks;
    return self;
}

- (NSFetchedResultsController *)createFetchedResultsController
{
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:[AwfulThread entityName]];
    request.predicate = [NSPredicate predicateWithFormat:@"isBookmarked = YES"];
    request.sortDescriptors = @[
        [NSSortDescriptor sortDescriptorWithKey:@"lastPostDate" ascending:NO]
    ];
    return [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                               managedObjectContext:self.managedObjectContext
                                                 sectionNameKeyPath:nil
                                                          cacheName:nil];
}

- (void)loadView
{
    [super loadView];
    [self.tableView registerClass:[AwfulThreadCell class] forCellReuseIdentifier:ThreadCellIdentifier];
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 60, 0, 0);
}

static NSString * const ThreadCellIdentifier = @"Thread Cell";

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.currentPage = 1;
    
    // Hide separators after the last cell.
    self.tableView.tableFooterView = [UIView new];
    self.tableView.tableFooterView.backgroundColor = [UIColor clearColor];
}

- (void)themeDidChange
{
	[super themeDidChange];
	self.view.backgroundColor = AwfulTheme.currentTheme[@"backgroundColor"];
}

#pragma mark - Table view controller

- (void)refresh
{
    [super refresh];
    [self.cellsMissingThreadTags removeAllObjects];
    [self loadPageNum:1];
}

- (BOOL)canPullForNextPage
{
    return YES;
}

- (void)nextPage
{
    [super nextPage];
    [self loadPageNum:self.currentPage + 1];
}

- (void)loadPageNum:(NSUInteger)pageNum
{   
    [self.networkOperation cancel];
    __weak __typeof__(self) weakSelf = self;
    __block id op = [[AwfulHTTPClient client] listBookmarkedThreadsOnPage:pageNum andThen:^(NSError *error, NSArray *threads) {
        __typeof__(self) self = weakSelf;
        if (![self.networkOperation isEqual:op]) return;
        if (error) {
            [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
        } else {
            if (pageNum == 1) {
                NSArray *bookmarks = [AwfulThread fetchAllInManagedObjectContext:self.managedObjectContext
                                                         matchingPredicateFormat:@"isBookmarked = YES"];
                [bookmarks setValue:@NO forKey:@"isBookmarked"];
                [threads setValue:@YES forKey:@"isBookmarked"];
                BOOL wasShowingBookmarkColors = self.showBookmarkColors;
                self.showBookmarkColors = NO;
                for (NSNumber *star in [bookmarks valueForKey:@"starCategory"]) {
                    NSInteger category = [star integerValue];
                    if (category == AwfulStarCategoryRed || category == AwfulStarCategoryYellow) {
                        self.showBookmarkColors = YES;
                        break;
                    }
                }
                self.ignoreUpdates = YES;
                NSError *error;
                BOOL ok = [self.managedObjectContext save:&error];
                if (!ok) {
                    NSLog(@"%s error loading bookmarks page %tu: %@", __PRETTY_FUNCTION__, pageNum, error);
                }
                self.ignoreUpdates = NO;
                self.lastRefreshDate = [NSDate date];
                if (self.showBookmarkColors != wasShowingBookmarkColors) {
                    [self.tableView reloadData];
                }
            }
            self.tableView.showsInfiniteScrolling = [threads count] >= 40;
        }
        self.currentPage = pageNum;
        self.refreshing = NO;
    }];
    self.networkOperation = op;
}

- (BOOL)refreshOnAppear
{
    if (![AwfulHTTPClient client].reachable) return NO;
    if ([self.tableView numberOfRowsInSection:0] == 0) return YES;
    if (!self.lastRefreshDate) return YES;
    return [[NSDate date] timeIntervalSinceDate:self.lastRefreshDate] > 60 * 10;
}

- (NSDate *)lastRefreshDate
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:kLastBookmarksRefreshDate];
}

- (void)setLastRefreshDate:(NSDate *)lastRefreshDate
{
    [[NSUserDefaults standardUserDefaults] setObject:lastRefreshDate
                                              forKey:kLastBookmarksRefreshDate];
}

static NSString * const kLastBookmarksRefreshDate = @"com.awfulapp.Awful.LastBookmarksRefreshDate";

#pragma mark - AwfulTableViewController

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulThreadCell *cell = [tableView dequeueReusableCellWithIdentifier:ThreadCellIdentifier
                                                            forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
	[self themeCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(AwfulThreadCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    UILongPressGestureRecognizer *longPress = [UILongPressGestureRecognizer new];
    [longPress addTarget:self action:@selector(showThreadActions:)];
    [cell addGestureRecognizer:longPress];
    AwfulThread *thread = [self.fetchedResultsController objectAtIndexPath:indexPath];
    // It's possible to pick the same tag for the first and second icons in e.g. SA Mart.
    // Since it'd look ugly to show the e.g. "Selling" banner for each tag image, we just use
    // the empty thread tag for anyone lame enough to pick the same tag twice.
    UIImage *emptyTag = [UIImage imageNamed:@"empty-thread-tag"];
    if ([thread.firstIconName isEqualToString:thread.secondIconName]) {
        cell.tagAndRatingView.threadTag = emptyTag;
    } else {
        UIImage *threadTag = [[AwfulThreadTags sharedThreadTags] threadTagNamed:thread.firstIconName];
        if (threadTag) {
            cell.tagAndRatingView.threadTag = threadTag;
        } else {
            cell.tagAndRatingView.threadTag = emptyTag;
            if (thread.firstIconName) {
                [self updateThreadTagsForCellAtIndexPath:indexPath];
            }
        }
    }
    UIImage *secondaryTag = [[AwfulThreadTags sharedThreadTags] threadTagNamed:thread.secondIconName];
    cell.tagAndRatingView.secondaryThreadTag = secondaryTag;
    if (!secondaryTag && thread.secondIconName) {
        [self updateThreadTagsForCellAtIndexPath:indexPath];
    }
    cell.stickyImageView.image = nil;
    // Hardcode Film Dump to never show ratings; its thread tags are the ratings.
    if ([thread.forum.forumID isEqualToString:@"133"]) {
        cell.tagAndRatingView.ratingImage = nil;
    } else {
        cell.tagAndRatingView.ratingImage = ThreadRatingImageForRating(thread.threadRating);
    }
    cell.textLabel.text = [thread.title stringByCollapsingWhitespace];
    if (thread.isSticky || !thread.isClosed) {
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
}

- (void)themeCell:(AwfulThreadCell *)cell atIndexPath:(id)indexPath
{
	[super themeCell:cell atIndexPath:indexPath];
	cell.backgroundColor = AwfulTheme.currentTheme[@"listBackgroundColor"];
	cell.badgeLabel.textColor = AwfulTheme.currentTheme[@"listTextColor"];
	cell.textLabel.textColor = AwfulTheme.currentTheme[@"listTextColor"];
}

static UIImage * ThreadRatingImageForRating(NSNumber *boxedRating)
{
    NSInteger rating = lroundf(boxedRating.floatValue);
    if (rating <= 0) return nil;
    if (rating < 1) {
        rating = 1;
    } else if (rating > 5) {
        rating = 5;
    }
    return [UIImage imageNamed:[NSString stringWithFormat:@"rating%zd", rating]];
}

- (void)updateThreadTagsForCellAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self.cellsMissingThreadTags count] == 0) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(newThreadTags:)
                                                     name:AwfulNewThreadTagsAvailableNotification
                                                   object:nil];
    }
    [self.cellsMissingThreadTags addObject:indexPath];
}

- (void)newThreadTags:(NSNotification *)note
{
    if ([self.cellsMissingThreadTags count] == 0) return;
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AwfulNewThreadTagsAvailableNotification
                                                  object:nil];
    [self.tableView reloadRowsAtIndexPaths:[self.cellsMissingThreadTags allObjects]
                          withRowAnimation:UITableViewRowAnimationNone];
    [self.cellsMissingThreadTags removeAllObjects];
}

- (void)showThreadActions:(UILongPressGestureRecognizer *)longPress
{
    if (longPress.state == UIGestureRecognizerStateBegan) {
        UITableViewCell *cell = (UITableViewCell *)longPress.view;
        NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
        AwfulThread *thread = [self.fetchedResultsController objectAtIndexPath:indexPath];
        [self showThreadActionsForThread:thread];
    }
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
    if (thread.isBookmarked) {
        bookmarkItemType = AwfulIconActionItemTypeRemoveBookmark;
    } else {
        bookmarkItemType = AwfulIconActionItemTypeAddBookmark;
    }
    [sheet addItem:[AwfulIconActionItem itemWithType:bookmarkItemType action:^{
        [[AwfulHTTPClient client] setThreadWithID:thread.threadID
                                     isBookmarked:!thread.isBookmarked
                                          andThen:^(NSError *error)
         {
             if (error) {
                 [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
             } else {
                 NSString *status = @"Removed Bookmark";
                 if (thread.isBookmarked) {
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
        [UIPasteboard generalPasteboard].items = @[ @{ (id)kUTTypeURL: [NSURL URLWithString:url],
                                                       (id)kUTTypePlainText: url }];
    }]];
    if (thread.beenSeen) {
        [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeMarkAsUnread
                                                  action:^{
                                                      [self markThreadUnseen:thread];
                                                  }]];
    }
    NSIndexPath *indexPath = [self.fetchedResultsController indexPathForObject:thread];
    // The cell can be nil if it's invisible or out of range. The table view is an acceptable fallback.
    UIView *view = [self.tableView cellForRowAtIndexPath:indexPath] ?: self.tableView;
    [sheet showFromRect:view.frame inView:self.tableView animated:YES];
}

- (void)markThreadUnseen:(AwfulThread *)thread
{
    if (!thread.threadID) {
        return NSLog(@"thread %@ is missing a thread ID; cannot mark unseen", thread.title);
    }
    [[AwfulHTTPClient client] forgetReadPostsInThreadWithID:thread.threadID
                                                    andThen:^(NSError *error)
     {
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
}

- (void)doneWithProfile
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
    forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        AwfulThread *thread = [self.fetchedResultsController objectAtIndexPath:indexPath];
        thread.isBookmarked = NO;
        self.networkOperation = [[AwfulHTTPClient client] setThreadWithID:thread.threadID
                                                             isBookmarked:NO
                                                                  andThen:^(NSError *error)
        {
            if (!error) return;
            thread.isBookmarked = YES;
            [AwfulAlertView showWithTitle:@"Error Removing Bbookmark"
                                    error:error
                              buttonTitle:@"Whatever"];
        }];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 75;
}

- (NSString *)tableView:(UITableView *)tableView
    titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return @"Unbookmark";
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulThread *thread = [self.fetchedResultsController objectAtIndexPath:indexPath];
    AwfulPostsViewController *page = [[AwfulPostsViewController alloc] initWithThread:thread];
    page.restorationIdentifier = @"AwfulPostsViewController";
    // For an unread thread, the Forums will interpret "next unread page" to mean "last page",
    // which is not very helpful.
    page.page = thread.beenSeen ? AwfulThreadPageNextUnread : 1;
    [self displayPage:page];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
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

@end
