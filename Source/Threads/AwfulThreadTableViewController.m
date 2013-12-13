//  AwfulThreadTableViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThreadTableViewController.h"
#import "AwfulAlertView.h"
#import "AwfulHTTPClient.h"
#import "AwfulIconActionSheet.h"
#import "AwfulPostsViewController.h"
#import "AwfulProfileViewController.h"
#import "AwfulSettings.h"
#import "AwfulTheme.h"
#import "AwfulThreadCell.h"
#import "AwfulThreadTag.h"
#import "AwfulThreadTagLoader.h"
#import "AwfulUIKitAndFoundationCategories.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import <SVPullToRefresh/SVPullToRefresh.h>

@implementation AwfulThreadTableViewController
{
    AwfulFetchedResultsControllerDataSource *_threadDataSource;
}

- (AwfulFetchedResultsControllerDataSource *)threadDataSource
{
    if (_threadDataSource) return _threadDataSource;
    _threadDataSource = [[AwfulFetchedResultsControllerDataSource alloc] initWithTableView:self.tableView
                                                                           reuseIdentifier:ThreadCellIdentifier];
    _threadDataSource.delegate = self;
    return _threadDataSource;
}

- (void)loadView
{
    [super loadView];
    [self.tableView registerClass:[AwfulThreadCell class] forCellReuseIdentifier:ThreadCellIdentifier];
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 60, 0, 0);
    [self.tableView awful_hideExtraneousSeparators];
}

static NSString * const ThreadCellIdentifier = @"Thread Cell";

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    _threadDataSource.updatesTableView = YES;
	[self themeDidChange];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    _threadDataSource.updatesTableView = NO;
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
    UIImage *emptyTag = [[AwfulThreadTagLoader loader] emptyThreadTagImage];
    if ([thread.threadTag isEqual:thread.secondaryThreadTag]) {
        cell.tagAndRatingView.threadTag = emptyTag;
    } else {
        UIImage *threadTag = [[AwfulThreadTagLoader loader] imageNamed:thread.threadTag.imageName];
        cell.tagAndRatingView.threadTag = threadTag ?: emptyTag;
    }
    if (thread.secondaryThreadTag) {
        UIImage *secondaryThreadTag = [[AwfulThreadTagLoader loader] imageNamed:thread.secondaryThreadTag.imageName];
        cell.tagAndRatingView.secondaryThreadTag = secondaryThreadTag;
    } else {
        cell.tagAndRatingView.secondaryThreadTag = nil;
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
        cell.badgeLabel.text = @(thread.unreadPosts).stringValue;
    } else {
        cell.detailTextLabel.text = [NSString stringWithFormat:@"Posted by %@", thread.author.username];
        cell.badgeLabel.text = nil;
    }
    [self themeCell:cell withObject:thread];
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
        AwfulPostsViewController *postsViewController = [[AwfulPostsViewController alloc] initWithThread:thread];
        postsViewController.restorationIdentifier = @"AwfulPostsViewController";
        [self showPostsViewController:postsViewController];
        postsViewController.page = 1;
    }]];
    [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeJumpToLastPage action:^{
        AwfulPostsViewController *postsViewController = [[AwfulPostsViewController alloc] initWithThread:thread];
        postsViewController.restorationIdentifier = @"AwfulPostsViewController";
        [self showPostsViewController:postsViewController];
        postsViewController.page = AwfulThreadPageLast;
    }]];
    AwfulIconActionItemType bookmarkItemType;
    if (thread.bookmarked) {
        bookmarkItemType = AwfulIconActionItemTypeRemoveBookmark;
    } else {
        bookmarkItemType = AwfulIconActionItemTypeAddBookmark;
    }
    [sheet addItem:[AwfulIconActionItem itemWithType:bookmarkItemType action:^{
        [[AwfulHTTPClient client] setThread:thread isBookmarked:!thread.bookmarked andThen:^(NSError *error) {
            if (error) {
                [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
            } else {
                NSString *status = thread.bookmarked ? @"Added Bookmark" : @"Removed Bookmark";
                [SVProgressHUD showSuccessWithStatus:status];
            }
        }];
    }]];
    if ([thread.author.userID length] > 0) {
        AwfulIconActionItem *profileItem = [AwfulIconActionItem itemWithType:AwfulIconActionItemTypeUserProfile action:^{
            AwfulProfileViewController *profile = [[AwfulProfileViewController alloc] initWithUser:thread.author];
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                [self presentViewController:[profile enclosingNavigationController] animated:YES completion:nil];
            } else {
                self.navigationItem.backBarButtonItem = [UIBarButtonItem emptyBackBarButtonItem];
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
            [[AwfulHTTPClient client] markThreadUnread:thread andThen:^(NSError *error) {
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

- (void)doneWithProfile
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showPostsViewController:(AwfulPostsViewController *)postsViewController
{
    if (self.expandingSplitViewController) {
        UINavigationController *nav = [postsViewController enclosingNavigationController];
        nav.restorationIdentifier = @"Navigation";
        self.expandingSplitViewController.detailViewController = nav;
    } else {
        [self.navigationController pushViewController:postsViewController animated:YES];
    }
}

- (void)themeCell:(AwfulThreadCell *)cell withObject:(AwfulThread *)thread
{
    cell.backgroundColor = self.theme[@"listBackgroundColor"];
    cell.textLabel.textColor = self.theme[@"listTextColor"];
    cell.tintColor = self.theme[@"listDetailColor"];
    cell.fontName = self.theme[@"listFontName"];
    if (thread.unreadPosts == 0) {
        cell.badgeLabel.textColor = [UIColor grayColor];
        cell.lightenBadgeLabel = YES;
    } else {
        switch (thread.starCategory) {
            case AwfulStarCategoryOrange: cell.badgeLabel.textColor = self.theme[@"unreadBadgeOrangeColor"]; break;
            case AwfulStarCategoryRed: cell.badgeLabel.textColor = self.theme[@"unreadBadgeRedColor"]; break;
            case AwfulStarCategoryYellow: cell.badgeLabel.textColor = self.theme[@"unreadBadgeYellowColor"]; break;
            default: cell.badgeLabel.textColor = self.theme[@"tintColor"]; break;
        }
        cell.lightenBadgeLabel = NO;
    }
}

- (void)themeCell:(AwfulThreadCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    [super themeCell:cell atIndexPath:indexPath];
    NSFetchedResultsController *fetchedResultsController = self.threadDataSource.fetchedResultsController;
    AwfulThread *thread = [fetchedResultsController objectAtIndexPath:indexPath];
    [self themeCell:cell withObject:thread];
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 75;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSFetchedResultsController *fetchedResultsController = self.threadDataSource.fetchedResultsController;
    AwfulThread *thread = [fetchedResultsController objectAtIndexPath:indexPath];
    AwfulPostsViewController *postsViewController = [[AwfulPostsViewController alloc] initWithThread:thread];
    postsViewController.restorationIdentifier = @"AwfulPostsViewController";
    
    // For an unread thread, the Forums will interpret "next unread page" to mean "last page", which is not very helpful.
    postsViewController.page = thread.beenSeen ? AwfulThreadPageNextUnread : 1;
    
    [self showPostsViewController:postsViewController];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
