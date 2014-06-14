//  AwfulThreadTableViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThreadTableViewController.h"
#import "AwfulActionViewController.h"
#import "AwfulAlertView.h"
#import "AwfulForumTweaks.h"
#import "AwfulForumsClient.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulNewThreadTagObserver.h"
#import "AwfulPostsViewController.h"
#import "AwfulProfileViewController.h"
#import "AwfulSettings.h"
#import "AwfulTheme.h"
#import "AwfulThreadCell.h"
#import "AwfulThreadTag.h"
#import "AwfulThreadTagLoader.h"
#import <MRProgress/MRProgressOverlayView.h>
#import <SVPullToRefresh/SVPullToRefresh.h>

@interface AwfulThreadTableViewController ()

@property (readonly, strong, nonatomic) NSMutableDictionary *threadTagObservers;

@end

@implementation AwfulThreadTableViewController
{
    AwfulFetchedResultsControllerDataSource *_threadDataSource;
}

@synthesize threadTagObservers = _threadTagObservers;

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
    self.tableView.rowHeight = 75;
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

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    _threadDataSource.updatesTableView = NO;
}

- (NSMutableDictionary *)threadTagObservers
{
    if (!_threadTagObservers) _threadTagObservers = [NSMutableDictionary new];
    return _threadTagObservers;
}

#pragma mark - AwfulFetchedResultsControllerDataSource

- (void)configureCell:(AwfulThreadCell *)cell withObject:(AwfulThread *)thread
{
    [cell.showActionsGestureRecognizer removeTarget:nil action:nil];
    [cell.showActionsGestureRecognizer addTarget:self action:@selector(showThreadActions:)];
    
	if ([AwfulSettings settings].showThreadTags) {
		cell.threadTagHidden = NO;
        AwfulThreadTagAndRatingView *tagAndRatingView = cell.tagAndRatingView;
        
		// It's possible to pick the same tag for the first and second icons in e.g. SA Mart. Since it'd look ugly to show the e.g. "Selling" banner for each tag image, we just use the empty thread tag for anyone lame enough to pick the same tag twice.
		if (thread.threadTag.imageName.length > 0 && ![thread.threadTag isEqual:thread.secondaryThreadTag]) {
            NSString *imageName = thread.threadTag.imageName;
			UIImage *image = [AwfulThreadTagLoader imageNamed:imageName];
			tagAndRatingView.threadTagImage = image;
            if (!image) {
                tagAndRatingView.threadTagImage = [AwfulThreadTagLoader emptyThreadTagImage];
                
                NSString *threadID = thread.threadID;
                AwfulNewThreadTagObserver *observer = [[AwfulNewThreadTagObserver alloc] initWithImageName:imageName downloadedBlock:^(UIImage *image) {
                    
                    // Make sure the cell represents the same thread it did when we started waiting for a new thread tag.
                    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
                    if (indexPath) {
                        AwfulThread *currentThread = [self.threadDataSource.fetchedResultsController objectAtIndexPath:indexPath];
                        if ([currentThread.threadID isEqualToString:threadID]) {
                            tagAndRatingView.threadTagImage = image;
                        }
                    }
                    [self.threadTagObservers removeObjectForKey:threadID];
                }];
                self.threadTagObservers[threadID] = observer;
            }
		} else {
            tagAndRatingView.threadTagImage = [AwfulThreadTagLoader emptyThreadTagImage];
		}
		if (thread.secondaryThreadTag) {
			UIImage *secondaryThreadTag = [AwfulThreadTagLoader imageNamed:thread.secondaryThreadTag.imageName];
			tagAndRatingView.secondaryThreadTagImage = secondaryThreadTag;
		} else {
			tagAndRatingView.secondaryThreadTagImage = nil;
		}
		
		if ([AwfulForumTweaks tweaksForForumId:thread.forum.forumID].showRatings) {
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
	} else {
		cell.threadTagHidden = YES;
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
    
    AwfulTheme *theme = self.theme;
    cell.backgroundColor = theme[@"listBackgroundColor"];
    cell.textLabel.textColor = theme[@"listTextColor"];
    cell.numberOfPagesLabel.textColor = theme[@"listSecondaryTextColor"];
    cell.detailTextLabel.textColor = theme[@"listSecondaryTextColor"];
    cell.tintColor = theme[@"listSecondaryTextColor"];
    cell.fontName = theme[@"listFontName"];
    UIView *selectedBackgroundView = [UIView new];
    selectedBackgroundView.backgroundColor = theme[@"listSelectedBackgroundColor"];
    cell.selectedBackgroundView = selectedBackgroundView;
    if (thread.unreadPosts == 0) {
        cell.badgeLabel.textColor = [UIColor grayColor];
        cell.lightenBadgeLabel = YES;
    } else {
        switch (thread.starCategory) {
            case AwfulStarCategoryOrange: cell.badgeLabel.textColor = theme[@"unreadBadgeOrangeColor"]; break;
            case AwfulStarCategoryRed: cell.badgeLabel.textColor = theme[@"unreadBadgeRedColor"]; break;
            case AwfulStarCategoryYellow: cell.badgeLabel.textColor = theme[@"unreadBadgeYellowColor"]; break;
            default: cell.badgeLabel.textColor = theme[@"tintColor"]; break;
        }
        cell.lightenBadgeLabel = NO;
    }
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
    AwfulActionViewController *sheet = [AwfulActionViewController new];
    [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeJumpToFirstPage action:^{
        AwfulPostsViewController *postsViewController = [[AwfulPostsViewController alloc] initWithThread:thread];
        postsViewController.restorationIdentifier = @"AwfulPostsViewController";
        [self showPostsViewController:postsViewController];
        [postsViewController loadPage:1 updatingCache:YES];
    }]];
    [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeJumpToLastPage action:^{
        AwfulPostsViewController *postsViewController = [[AwfulPostsViewController alloc] initWithThread:thread];
        postsViewController.restorationIdentifier = @"AwfulPostsViewController";
        [self showPostsViewController:postsViewController];
        [postsViewController loadPage:AwfulThreadPageLast updatingCache:YES];
    }]];
    AwfulIconActionItemType bookmarkItemType;
    if (thread.bookmarked) {
        bookmarkItemType = AwfulIconActionItemTypeRemoveBookmark;
    } else {
        bookmarkItemType = AwfulIconActionItemTypeAddBookmark;
    }
    [sheet addItem:[AwfulIconActionItem itemWithType:bookmarkItemType action:^{
        [[AwfulForumsClient client] setThread:thread isBookmarked:!thread.bookmarked andThen:^(NSError *error) {
            if (error) {
                [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
            } else {
                NSString *status = thread.bookmarked ? @"Added Bookmark" : @"Removed Bookmark";
                MRProgressOverlayView *overlay = [MRProgressOverlayView showOverlayAddedTo:self.view
                                                                                     title:status
                                                                                      mode:MRProgressOverlayViewModeCheckmark
                                                                                  animated:YES];
                overlay.tintColor = self.theme[@"tintColor"];
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [overlay dismiss:YES];
                });
            }
        }];
    }]];
    AwfulUser *author = thread.author;
    if (author.userID.length > 0 || author.username > 0) {
        AwfulIconActionItem *profileItem = [AwfulIconActionItem itemWithType:AwfulIconActionItemTypeUserProfile action:^{
            AwfulProfileViewController *profile = [[AwfulProfileViewController alloc] initWithUser:thread.author];
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                [self presentViewController:[profile enclosingNavigationController] animated:YES completion:nil];
            } else {
                self.navigationItem.backBarButtonItem = [UIBarButtonItem awful_emptyBackBarButtonItem];
                [self.navigationController pushViewController:profile animated:YES];
            }
        }];
        profileItem.title = @"View OP's Profile";
        [sheet addItem:profileItem];
    }
    [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeCopyURL action:^{
        NSURLComponents *components = [NSURLComponents componentsWithString:@"http://forums.somethingawful.com/showthread.php"];
        components.query = [@"threadid=" stringByAppendingString:thread.threadID];
        NSURL *URL = components.URL;
        [AwfulSettings settings].lastOfferedPasteboardURL = URL.absoluteString;
        [UIPasteboard generalPasteboard].awful_URL = URL;
    }]];
    if (thread.beenSeen) {
        [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeMarkAsUnread action:^{
            if (!thread.threadID) {
                return NSLog(@"thread %@ is missing a thread ID; cannot mark unseen", thread.title);
            }
            [[AwfulForumsClient client] markThreadUnread:thread andThen:^(NSError *error) {
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
    [sheet presentFromView:view highlightingRegionReturnedByBlock:^(UIView *view) {
        return CGRectInset(view.bounds, 0, 1);
    }];
}

- (void)doneWithProfile
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)showPostsViewController:(AwfulPostsViewController *)postsViewController
{
    if (self.splitViewController) {
        [self.splitViewController setDetailViewController:[postsViewController enclosingNavigationController]
                                            sidebarHidden:YES
                                                 animated:YES];
    } else {
        [self.navigationController pushViewController:postsViewController animated:YES];
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSFetchedResultsController *fetchedResultsController = self.threadDataSource.fetchedResultsController;
    AwfulThread *thread = [fetchedResultsController objectAtIndexPath:indexPath];
    AwfulPostsViewController *postsViewController = [[AwfulPostsViewController alloc] initWithThread:thread];
    postsViewController.restorationIdentifier = @"AwfulPostsViewController";
    
    // SA: For an unread thread, the Forums will interpret "next unread page" to mean "last page", which is not very helpful.
    [postsViewController loadPage:(thread.beenSeen ? AwfulThreadPageNextUnread : 1) updatingCache:YES];
    
    [self showPostsViewController:postsViewController];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
