//  AbstractThreadListViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AbstractThreadListViewController.h"
#import "AwfulForumTweaks.h"
#import "AwfulForumsClient.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulNewThreadTagObserver.h"
#import "AwfulSettings.h"
#import "AwfulTheme.h"
#import "AwfulThreadTag.h"
#import "AwfulThreadTagLoader.h"
#import "PostsPageViewController.h"
#import <MRProgress/MRProgressOverlayView.h>
#import <SVPullToRefresh/SVPullToRefresh.h>
#import "Awful-Swift.h"

@interface AbstractThreadListViewController ()

@property (strong, nonatomic) AwfulFetchedResultsControllerDataSource *threadDataSource;
@property (strong, nonatomic) NSMutableDictionary *threadTagObservers;
@property (strong, nonatomic) id <NSObject> settingsObserver;

@end

@implementation AbstractThreadListViewController

- (void)dealloc
{
    if (_settingsObserver) {
        [[NSNotificationCenter defaultCenter] removeObserver:_settingsObserver];
    }
}

- (AwfulFetchedResultsControllerDataSource *)threadDataSource
{
    if (!_threadDataSource) {
        _threadDataSource = [[AwfulFetchedResultsControllerDataSource alloc] initWithTableView:self.tableView reuseIdentifier:ThreadCellIdentifier];
        _threadDataSource.delegate = self;
    }
    return _threadDataSource;
}

- (void)loadView
{
    [super loadView];
    [self.tableView registerNib:[UINib nibWithNibName:@"ThreadCell" bundle:nil] forCellReuseIdentifier:ThreadCellIdentifier];
    self.tableView.estimatedRowHeight = 75;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
}

static NSString * const ThreadCellIdentifier = @"Thread";

- (void)viewDidLoad
{
    [super viewDidLoad];
    __weak __typeof__(self) weakSelf = self;
    _settingsObserver = [[NSNotificationCenter defaultCenter] addObserverForName:AwfulSettingsDidChangeNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notification) {
        if ([notification.userInfo[AwfulSettingsDidChangeSettingKey] isEqual:AwfulSettingsKeys.showThreadTags]) {
            __typeof__(self) self = weakSelf;
            [self.tableView reloadData];
        }
    }];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    _threadDataSource.updatesTableView = YES;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    _threadDataSource.updatesTableView = NO;
}

- (NSMutableDictionary *)threadTagObservers
{
    if (!_threadTagObservers) {
        _threadTagObservers = [NSMutableDictionary new];
    }
    return _threadTagObservers;
}

- (UIEdgeInsets)appropriateSeparatorInset
{
    // The minimum inset is the cell's layoutMargins, so 0 is effectively 16 here, just without hardcoding the 16.
    CGFloat left = [AwfulSettings sharedSettings].showThreadTags ? 61 : 0;
    return UIEdgeInsetsMake(0, left, 0, 0);
}

#pragma mark - AwfulFetchedResultsControllerDataSource

- (void)configureCell:(ThreadCell *)cell withObject:(AwfulThread *)thread
{
    // TODO Swift weirdness here, declaring -setLongPressTarget:action:'s second parameter as type `Selector` prevented it from appearing in Awful-Swift.h.
    [cell setLongPressTarget:self action:@"showThreadActions:"];
    
	if ([AwfulSettings sharedSettings].showThreadTags) {
		cell.showsTag = YES;
        
		// It's possible to pick the same tag for the first and second icons in e.g. SA Mart. Since it'd look ugly to show the e.g. "Selling" banner for each tag image, we just use the empty thread tag for anyone lame enough to pick the same tag twice.
		if (thread.threadTag.imageName.length > 0 && ![thread.threadTag isEqual:thread.secondaryThreadTag]) {
            NSString *imageName = thread.threadTag.imageName;
			UIImage *image = [AwfulThreadTagLoader imageNamed:imageName];
            cell.tagImageView.image = image;
            if (!image) {
                cell.tagImageView.image = [AwfulThreadTagLoader emptyThreadTagImage];
                
                NSString *threadID = thread.threadID;
                AwfulNewThreadTagObserver *observer = [[AwfulNewThreadTagObserver alloc] initWithImageName:imageName downloadedBlock:^(UIImage *image) {
                    
                    // Make sure the cell represents the same thread it did when we started waiting for a new thread tag.
                    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
                    if (indexPath) {
                        AwfulThread *currentThread = [self.threadDataSource.fetchedResultsController objectAtIndexPath:indexPath];
                        if ([currentThread.threadID isEqualToString:threadID]) {
                            cell.tagImageView.image = image;
                        }
                    }
                    [self.threadTagObservers removeObjectForKey:threadID];
                }];
                self.threadTagObservers[threadID] = observer;
            }
		} else {
            cell.tagImageView.image = [AwfulThreadTagLoader emptyThreadTagImage];
		}
		if (thread.secondaryThreadTag) {
			UIImage *secondaryThreadTag = [AwfulThreadTagLoader imageNamed:thread.secondaryThreadTag.imageName];
            cell.secondaryTagImageView.image = secondaryThreadTag;
            cell.secondaryTagImageView.hidden = NO;
		} else {
            cell.secondaryTagImageView.hidden = YES;
		}
		
		if ([AwfulForumTweaks tweaksForForumId:thread.forum.forumID].showRatings) {
            cell.showsRating = NO;
		} else {
			NSInteger rating = lroundf(thread.rating.floatValue);
			if (rating <= 0) {
                cell.showsRating = NO;
			} else {
				if (rating < 1) {
					rating = 1;
				} else if (rating > 5) {
					rating = 5;
				}
                cell.showsRating = YES;
                cell.ratingImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"rating%zd", rating]];
			}
		}
	} else {
		cell.showsTag = NO;
	}
	
    cell.separatorInset = [self appropriateSeparatorInset];
	
    cell.titleLabel.text = [thread.title stringByCollapsingWhitespace];
    if (thread.sticky || !thread.closed) {
        cell.tagAndRatingContainerView.alpha = 1;
        cell.titleLabel.enabled = YES;
    } else {
        cell.tagAndRatingContainerView.alpha = 0.5;
        cell.titleLabel.enabled = NO;
    }
    cell.numberOfPagesLabel.text = @(thread.numberOfPages).stringValue;
    if (thread.beenSeen) {
        cell.killedByLabel.text = [NSString stringWithFormat:@"Killed by %@", thread.lastPostAuthorName];
        cell.unreadRepliesLabel.text = @(thread.unreadPosts).stringValue;
    } else {
        cell.killedByLabel.text = [NSString stringWithFormat:@"Posted by %@", thread.author.username];
        cell.unreadRepliesLabel.text = nil;
    }
    
    AwfulTheme *theme = self.theme;
    cell.backgroundColor = theme[@"listBackgroundColor"];
    cell.titleLabel.textColor = theme[@"listTextColor"];
    cell.numberOfPagesLabel.textColor = theme[@"listSecondaryTextColor"];
    cell.killedByLabel.textColor = theme[@"listSecondaryTextColor"];
    cell.tintColor = theme[@"listSecondaryTextColor"];
    [cell setFontNameForLabels:theme[@"listFontName"]];
    cell.separator.backgroundColor = theme[@"listSeparatorColor"];
    UIView *selectedBackgroundView = [UIView new];
    selectedBackgroundView.backgroundColor = theme[@"listSelectedBackgroundColor"];
    cell.selectedBackgroundView = selectedBackgroundView;
    if (thread.unreadPosts == 0) {
        cell.unreadRepliesLabel.textColor = [UIColor grayColor];
    } else {
        switch (thread.starCategory) {
            case AwfulStarCategoryOrange: cell.unreadRepliesLabel.textColor = theme[@"unreadBadgeOrangeColor"]; break;
            case AwfulStarCategoryRed: cell.unreadRepliesLabel.textColor = theme[@"unreadBadgeRedColor"]; break;
            case AwfulStarCategoryYellow: cell.unreadRepliesLabel.textColor = theme[@"unreadBadgeYellowColor"]; break;
            default: cell.unreadRepliesLabel.textColor = theme[@"tintColor"]; break;
        }
    }
}

- (void)showThreadActions:(ThreadCell *)cell
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    AwfulThread *thread = [_threadDataSource.fetchedResultsController objectAtIndexPath:indexPath];
    [self showThreadActionsForThread:thread];
}

- (void)showThreadActionsForThread:(AwfulThread *)thread
{
    InAppActionViewController *actionViewController = [InAppActionViewController new];
    NSMutableArray *items = [NSMutableArray new];
    [items addObject:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeJumpToFirstPage action:^{
        PostsPageViewController *postsViewController = [[PostsPageViewController alloc] initWithThread:thread];
        postsViewController.restorationIdentifier = @"AwfulPostsViewController";
        [postsViewController loadPage:1 updatingCache:YES];
        [self showDetailViewController:postsViewController sender:self];
    }]];
    [items addObject:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeJumpToLastPage action:^{
        PostsPageViewController *postsViewController = [[PostsPageViewController alloc] initWithThread:thread];
        postsViewController.restorationIdentifier = @"AwfulPostsViewController";
        [postsViewController loadPage:AwfulThreadPageLast updatingCache:YES];
        [self showDetailViewController:postsViewController sender:self];
    }]];
    AwfulIconActionItemType bookmarkItemType;
    if (thread.bookmarked) {
        bookmarkItemType = AwfulIconActionItemTypeRemoveBookmark;
    } else {
        bookmarkItemType = AwfulIconActionItemTypeAddBookmark;
    }
    [items addObject:[AwfulIconActionItem itemWithType:bookmarkItemType action:^{
        [[AwfulForumsClient client] setThread:thread isBookmarked:!thread.bookmarked andThen:^(NSError *error) {
            if (error) {
                [self presentViewController:[UIAlertController alertWithNetworkError:error] animated:YES completion:nil];
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
            ProfileViewController *profile = [[ProfileViewController alloc] initWithUser:thread.author];
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                [self presentViewController:[profile enclosingNavigationController] animated:YES completion:nil];
            } else {
                self.navigationItem.backBarButtonItem = [UIBarButtonItem awful_emptyBackBarButtonItem];
                [self.navigationController pushViewController:profile animated:YES];
            }
        }];
        profileItem.title = @"View OP's Profile";
        [items addObject:profileItem];
    }
    [items addObject:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeCopyURL action:^{
        NSURLComponents *components = [NSURLComponents componentsWithString:@"http://forums.somethingawful.com/showthread.php"];
        components.query = [@"threadid=" stringByAppendingString:thread.threadID];
        NSURL *URL = components.URL;
        [AwfulSettings sharedSettings].lastOfferedPasteboardURL = URL.absoluteString;
        [UIPasteboard generalPasteboard].awful_URL = URL;
    }]];
    if (thread.beenSeen) {
        [items addObject:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeMarkAsUnread action:^{
            if (!thread.threadID) {
                return NSLog(@"thread %@ is missing a thread ID; cannot mark unseen", thread.title);
            }
            [[AwfulForumsClient client] markThreadUnread:thread andThen:^(NSError *error) {
                if (error) {
                    [self presentViewController:[UIAlertController alertWithNetworkError:error] animated:YES completion:nil];
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
    
    actionViewController.items = items;
    actionViewController.popoverPositioningBlock = ^(CGRect *sourceRect, UIView * __autoreleasing *sourceView) {
        NSIndexPath *indexPath = [_threadDataSource.fetchedResultsController indexPathForObject:thread];
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        *sourceRect = cell.bounds;
        *sourceView = cell;
    };
    [self presentViewController:actionViewController animated:YES completion:nil];
}

- (void)doneWithProfile
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSFetchedResultsController *fetchedResultsController = self.threadDataSource.fetchedResultsController;
    AwfulThread *thread = [fetchedResultsController objectAtIndexPath:indexPath];
    PostsPageViewController *postsViewController = [[PostsPageViewController alloc] initWithThread:thread];
    postsViewController.restorationIdentifier = @"Posts";
    
    // SA: For an unread thread, the Forums will interpret "next unread page" to mean "last page", which is not very helpful.
    [postsViewController loadPage:(thread.beenSeen ? AwfulThreadPageNextUnread : 1) updatingCache:YES];
    
    [self showDetailViewController:postsViewController sender:self];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
