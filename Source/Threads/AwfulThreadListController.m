//  AwfulThreadListController.m
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThreadListController.h"
#import "AwfulFetchedTableViewControllerSubclass.h"
#import "AwfulActionSheet.h"
#import "AwfulAlertView.h"
#import "AwfulDataStack.h"
#import "AwfulExpandingSplitViewController.h"
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
#import "UIViewController+NavigationEnclosure.h"

@interface AwfulThreadListController () <AwfulThreadComposeViewControllerDelegate>

@property (nonatomic) NSMutableSet *cellsMissingThreadTags;
@property (nonatomic) UIBarButtonItem *newThreadButtonItem;

@end


@implementation AwfulThreadListController

- (id)init
{
    if (!(self = [super init])) return nil;
    _cellsMissingThreadTags = [NSMutableSet new];
    self.navigationItem.rightBarButtonItem = self.newThreadButtonItem;
    return self;
}

- (UIBarButtonItem* )newThreadButtonItem
{
    if (_newThreadButtonItem) return _newThreadButtonItem;
    _newThreadButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose
                                                                         target:self
                                                                         action:@selector(didTapNewThreadButtonItem)];
    return _newThreadButtonItem;
}

- (void)didTapNewThreadButtonItem
{
    AwfulThreadComposeViewController *compose = [[AwfulThreadComposeViewController alloc]
                                                 initWithForum:self.forum];
    compose.delegate = self;
    [self presentViewController:[compose enclosingNavigationController] animated:YES
                     completion:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSFetchedResultsController *)createFetchedResultsController
{
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:[AwfulThread entityName]];
    request.predicate = [NSPredicate predicateWithFormat:@"hideFromList == NO AND forum == %@",
                         self.forum];
    request.sortDescriptors = @[
        [NSSortDescriptor sortDescriptorWithKey:@"stickyIndex" ascending:YES],
        [NSSortDescriptor sortDescriptorWithKey:@"lastPostDate" ascending:NO]
    ];
    return [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                               managedObjectContext:[AwfulDataStack sharedDataStack].context
                                                 sectionNameKeyPath:nil
                                                          cacheName:nil];
}

- (void)setForum:(AwfulForum *)forum
{
    if (_forum == forum) return;
    self.fetchedResultsController.delegate = nil;
    self.fetchedResultsController = nil;
    _forum = forum;
    self.title = _forum.name;
    self.navigationItem.backBarButtonItem = [self abbreviatedBackBarButtonItem];
}

- (UIBarButtonItem *)abbreviatedBackBarButtonItem
{
    NSURL *abbreviationsURL = [[NSBundle mainBundle] URLForResource:@"Forum Abbreviations"
                                                      withExtension:@"plist"];
    NSDictionary *abbreviations = [NSDictionary dictionaryWithContentsOfURL:abbreviationsURL];
    NSString *text = abbreviations[self.forum.forumID];
    if (!text) return nil;
    return [[UIBarButtonItem alloc] initWithTitle:text style:UIBarButtonItemStyleBordered
                                           target:nil
                                           action:NULL];
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

- (BOOL)refreshOnAppear
{
    if (![AwfulHTTPClient client].reachable) return NO;
    if (!self.forum.lastRefresh) return YES;
    if ([self.fetchedResultsController.fetchedObjects count] == 0) return YES;
    return [[NSDate date] timeIntervalSinceDate:self.forum.lastRefresh] > 60 * 15;
}

- (void)nextPage
{
    [super nextPage];
    [self loadPageNum:self.currentPage + 1];
}

- (void)loadPageNum:(NSUInteger)pageNum
{    
    [self.networkOperation cancel];
    __block id op;
    op = [[AwfulHTTPClient client] listThreadsInForumWithID:self.forum.forumID
                                                     onPage:pageNum
                                                    andThen:^(NSError *error, NSArray *threads)
    {
        if (![self.networkOperation isEqual:op]) return;
        if (error) {
            [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
        } else {
            if (pageNum == 1) {
                [self.forum.threads setValue:@YES forKey:@"hideFromList"];
            }
            [threads setValue:@NO forKey:@"hideFromList"];
            self.forum.lastRefresh = [NSDate date];
            self.ignoreUpdates = YES;
            [[AwfulDataStack sharedDataStack] save];
            self.ignoreUpdates = NO;
            self.currentPage = pageNum;
        }
        self.refreshing = NO;
    }];
    self.networkOperation = op;
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

- (void)showThreadActionsForThread:(AwfulThread *)thread
{
    AwfulIconActionSheet *sheet = [AwfulIconActionSheet new];
    sheet.title = [thread.title stringByCollapsingWhitespace];
    [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeJumpToFirstPage
                                              action:^
    {
        AwfulPostsViewController *page = [AwfulPostsViewController new];
        page.restorationIdentifier = @"AwfulPostsViewController";
        page.thread = thread;
        [self displayPage:page];
        [page loadPage:1 singleUserID:nil];
    }]];
    [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeJumpToLastPage action:^{
        AwfulPostsViewController *page = [AwfulPostsViewController new];
        page.restorationIdentifier = @"AwfulPostsViewController";
        page.thread = thread;
        [self displayPage:page];
        [page loadPage:AwfulThreadPageLast singleUserID:nil];
    }]];
    AwfulIconActionItemType bookmarkItemType;
    if (thread.isBookmarkedValue) {
        bookmarkItemType = AwfulIconActionItemTypeRemoveBookmark;
    } else {
        bookmarkItemType = AwfulIconActionItemTypeAddBookmark;
    }
    [sheet addItem:[AwfulIconActionItem itemWithType:bookmarkItemType action:^{
        [[AwfulHTTPClient client] setThreadWithID:thread.threadID
                                     isBookmarked:!thread.isBookmarkedValue
                                          andThen:^(NSError *error)
         {
             if (error) {
                 [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
             } else {
                 NSString *status = @"Removed Bookmark";
                 if (thread.isBookmarkedValue) {
                     status = @"Added Bookmark";
                 }
                 [SVProgressHUD showSuccessWithStatus:status];
             }
         }];
    }]];
    if ([thread.author.userID length] > 0) {
        AwfulIconActionItem *profileItem = [AwfulIconActionItem itemWithType:
                                            AwfulIconActionItemTypeUserProfile action:^{
            AwfulProfileViewController *profile = [AwfulProfileViewController new];
            profile.hidesBottomBarWhenPushed = YES;
            profile.userID = thread.author.userID;
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
        [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeMarkAsUnread
                                                  action:^{
            [self markThreadUnseen:thread];
        }]];
    }
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        NSIndexPath *indexPath = [self.fetchedResultsController indexPathForObject:thread];
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        // We've seen the occasional crash result from the cell being nil, i.e. invisible or out of
        // range. Fall back to pointing at the table view.
        [sheet presentFromViewController:self fromRect:CGRectZero inView:cell ?: self.tableView];
    } else {
        [sheet presentFromViewController:self fromRect:CGRectZero inView:self.view];
    }
}

- (void)doneWithProfile
{
    [self dismissViewControllerAnimated:YES completion:nil];
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
            thread.seenPostsValue = 0;
            [[AwfulDataStack sharedDataStack] save];
        }
    }];
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

#pragma mark - UITableViewDataSource and UITableViewDelegate

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulThreadCell *cell = [tableView dequeueReusableCellWithIdentifier:ThreadCellIdentifier
                                                            forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
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
    if (thread.isStickyValue) {
        cell.stickyImageView.image = [UIImage imageNamed:@"sticky"];
    } else {
        cell.stickyImageView.image = nil;
    }
    // Hardcode Film Dump to never show ratings; its thread tags are the ratings.
    if ([thread.forum.forumID isEqualToString:@"133"]) {
        cell.tagAndRatingView.ratingImage = nil;
    } else {
        cell.tagAndRatingView.ratingImage = ThreadRatingImageForRating(thread.threadRating);
    }
    cell.textLabel.text = [thread.title stringByCollapsingWhitespace];
    if (thread.isStickyValue || !thread.isClosedValue) {
        cell.tagAndRatingView.alpha = 1;
        cell.textLabel.enabled = YES;
    } else {
        cell.tagAndRatingView.alpha = 0.5;
        cell.textLabel.enabled = NO;
    }
    cell.numberOfPagesLabel.text = thread.numberOfPages.stringValue;
    if (thread.beenSeen) {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Killed by %@", thread.lastPostAuthorName];
    } else {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Posted by %@", thread.author.username];
    }
    NSInteger unreadPosts = thread.totalRepliesValue + 1 - thread.seenPostsValue;
    cell.badgeLabel.text = @(unreadPosts).stringValue;
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
    return [UIImage imageNamed:[NSString stringWithFormat:@"rating%d", rating]];
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

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 75;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulThread *thread = [self.fetchedResultsController objectAtIndexPath:indexPath];
    return thread.seenPostsValue > 0;
}

- (NSString *)tableView:(UITableView *)tableView
    titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return @"Mark Unread";
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
    forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        AwfulThread *thread = [self.fetchedResultsController objectAtIndexPath:indexPath];
        [self markThreadUnseen:thread];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
    AwfulPostsViewController *page = [AwfulPostsViewController new];
    page.restorationIdentifier = @"AwfulPostsViewController";
    AwfulThread *thread = [self.fetchedResultsController objectAtIndexPath:indexPath];
    page.thread = thread;
    // For an unread thread, the Forums will interpret "next unread page" to mean "last page",
    // which is not very helpful.
    [page loadPage:thread.beenSeen ? AwfulThreadPageNextUnread : 1
      singleUserID:nil];
    [self displayPage:page];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - AwfulThreadComposeViewControllerDelegate

- (void)threadComposeController:(AwfulThreadComposeViewController *)controller
            didPostThreadWithID:(NSString *)threadID
{
    [self dismissViewControllerAnimated:YES completion:nil];
    AwfulPostsViewController *page = [AwfulPostsViewController new];
    page.restorationIdentifier = @"AwfulPostsViewController";
    page.thread = [AwfulThread firstOrNewThreadWithThreadID:threadID];
    [page loadPage:1 singleUserID:nil];
    [self displayPage:page];
}

- (void)threadComposeControllerDidCancel:(AwfulThreadComposeViewController *)controller
{
    // TODO save draft?
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark State preservation and restoration

+ (UIViewController *)viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    AwfulThreadListController *threadList = [self new];
    threadList.restorationIdentifier = identifierComponents.lastObject;
    threadList.restorationClass = self;
    return threadList;
}

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeObject:self.forum.forumID forKey:ForumIDKey];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];
    self.forum = [AwfulForum firstMatchingPredicate:@"forumID = %@", [coder decodeObjectForKey:ForumIDKey]];
}

static NSString * const ForumIDKey = @"AwfulForumID";

@end
