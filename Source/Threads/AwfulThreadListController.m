//  AwfulThreadListController.m
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulThreadListController.h"
#import "AwfulFetchedTableViewControllerSubclass.h"
#import "AwfulActionSheet.h"
#import "AwfulAlertView.h"
#import "AwfulDataStack.h"
#import "AwfulDisclosureIndicatorView.h"
#import "AwfulHTTPClient.h"
#import "AwfulIconActionSheet.h"
#import "AwfulLoginController.h"
#import "AwfulModels.h"
#import "AwfulPlainBarButtonItem.h"
#import "AwfulPostsViewController.h"
#import "AwfulProfileViewController.h"
#import "AwfulSettings.h"
#import "AwfulSplitViewController.h"
#import "AwfulTabBarController.h"
#import "AwfulTheme.h"
#import "AwfulThreadCell.h"
#import "AwfulThreadComposeViewController.h"
#import "AwfulThreadTag.h"
#import "AwfulThreadTagFilterController.h"
#import "AwfulThreadTags.h"
#import "NSString+CollapseWhitespace.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import "UIViewController+NavigationEnclosure.h"

@interface AwfulThreadListController () <AwfulThreadComposeViewControllerDelegate,
                                            AwfulPostIconPickerControllerDelegate>

@property (nonatomic) NSMutableSet *cellsMissingThreadTags;
@property (nonatomic) UIBarButtonItem *newThreadButtonItem;
@property (nonatomic) UIBarButtonItem *filterButtonItem;
@property (nonatomic) AwfulThreadTagFilterController *filterPicker;
@property (copy, nonatomic) NSArray *availablePostIcons;
@property (nonatomic) AwfulThreadTag *postIcon;

@end


@implementation AwfulThreadListController

- (id)init
{
    if (!(self = [super init])) return nil;
    _cellsMissingThreadTags = [NSMutableSet new];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsChanged:)
                                                 name:AwfulSettingsDidChangeNotification
                                               object:nil];
    self.navigationItem.rightBarButtonItems = @[self.newThreadButtonItem, self.filterButtonItem];
    return self;
}

- (UIBarButtonItem* )newThreadButtonItem
{
    if (_newThreadButtonItem) return _newThreadButtonItem;
    _newThreadButtonItem = [[AwfulPlainBarButtonItem alloc]
                            initWithBarButtonSystemItem:UIBarButtonSystemItemCompose
                            target:self action:@selector(didTapNewThreadButtonItem)];
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

- (UIBarButtonItem* )filterButtonItem
{
    if (_filterButtonItem) return _filterButtonItem;
    _filterButtonItem = [[AwfulPlainBarButtonItem alloc]
                        initWithBarButtonSystemItem:UIBarButtonSystemItemSearch
                        target:self action:@selector(didTapFilterButtonItem)];
    return _filterButtonItem;
}

- (void)didTapFilterButtonItem
{
    if (!self.filterPicker) {
        self.filterPicker = [[AwfulThreadTagFilterController alloc] initWithDelegate:self];
        [self.filterPicker reloadData];
    }
    if (self.postIcon) {
        NSUInteger index = [self.availablePostIcons indexOfObject:self.postIcon];
        self.filterPicker.selectedIndex = index;
    } else {
        self.filterPicker.selectedIndex = 0;
    }
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.filterPicker showFromBarButtonItem:self.filterButtonItem];
    } else {
        [self presentViewController:[self.filterPicker enclosingNavigationController]
                           animated:YES
                         completion:nil];
    }
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

- (void)settingsChanged:(NSNotification *)note
{
    if (![self isViewLoaded]) return;
    NSArray *keys = note.userInfo[AwfulSettingsDidChangeSettingsKey];
    if ([keys containsObject:AwfulSettingsKeys.showThreadTags]) {
        [self.tableView reloadData];
    }
}

#pragma mark - AwfulPostIconPickerControllerDelegate

- (NSInteger)numberOfIconsInPostIconPicker:(AwfulPostIconPickerController *)picker
{
    // +1 for the empty thread tag.
    return [self.availablePostIcons count] + 1;
}

- (UIImage *)postIconPicker:(AwfulPostIconPickerController *)picker postIconAtIndex:(NSInteger)index
{
    // -1 for the "empty thread" tag.
    index -= 1;
    if (index < 0) {
        return [UIImage imageNamed:[AwfulThreadTag emptyThreadTagImageName]];
    } else {
        NSString *iconName = [self.availablePostIcons[index] imageName];
        return [[AwfulThreadTags sharedThreadTags] threadTagNamed:iconName];
    }
}

- (void)postIconPickerDidComplete:(AwfulPostIconPickerController *)picker
{
    NSInteger index = picker.selectedIndex - 1;
    if (index < 0 || index > (NSInteger)self.availablePostIcons.count) {
        self.postIcon = nil;
        self.filterButtonItem.tintColor = [UIColor whiteColor];
    } else {
        self.postIcon = self.availablePostIcons[index];
        self.filterButtonItem.tintColor = [UIColor yellowColor];
        self.forum.lastRefresh = nil;
    }
    
    self.filterPicker = nil;
    [self dismissViewControllerAnimated:YES completion:nil];
    [self refresh];
}

- (void)postIconPickerDidCancel:(AwfulPostIconPickerController *)picker
{
    self.filterPicker = nil;
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)postIconPicker:(AwfulPostIconPickerController *)picker didSelectIconAtIndex:(NSInteger)index
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        index -= 1;
        if (index < 0 || index > (NSInteger)self.availablePostIcons.count) {
            self.postIcon = nil;
            self.filterButtonItem.tintColor = [UIColor whiteColor];
        } else {
            self.postIcon = self.availablePostIcons[index];
            self.filterButtonItem.tintColor = [UIColor yellowColor];
            self.forum.lastRefresh = nil;
        }
    }
    [self refresh];
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

- (void)retheme
{
    [super retheme];
    self.view.backgroundColor = [AwfulTheme currentTheme].threadListBackgroundColor;
    self.tableView.separatorColor = [AwfulTheme currentTheme].threadListSeparatorColor;
}

- (void)loadPageNum:(NSUInteger)pageNum
{    
    [self.networkOperation cancel];
    __block id op;
    op = [[AwfulHTTPClient client] listThreadsInForumWithID:self.forum.forumID
                                                  threadTag:self.postIcon.composeID
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

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.currentPage = 1;
    self.tableView.rowHeight = 75;
    
    // Hide separators after the last cell.
    self.tableView.tableFooterView = [UIView new];
    self.tableView.tableFooterView.backgroundColor = [UIColor clearColor];

    if (self.forum.forumID) {
        [[AwfulHTTPClient client] listAvailablePostIconsForForumWithID:self.forum.forumID
                                                               andThen:^(NSError *error,
                                                                         NSArray *postIcons,
                                                                         NSArray *secondaryPostIcons,
                                                                         NSString *secondaryIconKey)
         {
             self.availablePostIcons = postIcons;
             [self.filterPicker reloadData];
         }];
    }
}

- (void)showThreadActionsForThread:(AwfulThread *)thread
{
    AwfulIconActionSheet *sheet = [AwfulIconActionSheet new];
    sheet.title = [thread.title stringByCollapsingWhitespace];
    [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeJumpToFirstPage
                                              action:^{
        AwfulPostsViewController *page = [AwfulPostsViewController new];
        page.thread = thread;
        [self displayPage:page];
        [page loadPage:1 singleUserID:nil];
    }]];
    [sheet addItem:[AwfulIconActionItem itemWithType:AwfulIconActionItemTypeJumpToLastPage action:^{
        AwfulPostsViewController *page = [AwfulPostsViewController new];
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
        AwfulTabBar *tabBar = self.awfulTabBarController.tabBar;
        [sheet presentFromViewController:self.awfulTabBarController
                                fromRect:tabBar.bounds inView:tabBar];
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
    AwfulSplitViewController *split = self.awfulSplitViewController;
    if (split) {
        UINavigationController *nav = (id)split.mainViewController;
        nav.viewControllers = @[ page ];
        [split setSidebarVisible:NO animated:YES];
    } else {
        [self.navigationController pushViewController:page animated:YES];
    }
}

#pragma mark - UITableViewDataSource and UITableViewDelegate

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * const Identifier = @"AwfulThreadCell";
    AwfulThreadCell *cell = [tableView dequeueReusableCellWithIdentifier:Identifier];
    if (!cell) {
        cell = [[AwfulThreadCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:Identifier];
        cell.stickyImageViewOffset = CGSizeMake(1, 1);
        UILongPressGestureRecognizer *longPress = [UILongPressGestureRecognizer new];
        [longPress addTarget:self action:@selector(showThreadActions:)];
        [cell addGestureRecognizer:longPress];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
            cell.accessoryView = [AwfulDisclosureIndicatorView new];
        }
    }
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(UITableViewCell *)genericCell atIndexPath:(NSIndexPath *)indexPath
{
    AwfulThreadCell *cell = (id)genericCell;
    AwfulThread *thread = [self.fetchedResultsController objectAtIndexPath:indexPath];
    if ([AwfulSettings settings].showThreadTags) {
        // It's possible to pick the same tag for the first and second icons in e.g. SA Mart.
        // Since it'd look ugly to show the e.g. "Selling" banner for each tag image, we just use
        // the empty thread tag for anyone lame enough to pick the same tag twice.
        if ([thread.firstIconName isEqualToString:thread.secondIconName]) {
            cell.icon = [UIImage imageNamed:@"empty-thread-tag"];
        } else {
            cell.icon = [[AwfulThreadTags sharedThreadTags] threadTagNamed:thread.firstIconName];
            if (!cell.icon && thread.firstIconName) {
                [self updateThreadTagsForCellAtIndexPath:indexPath];
                cell.icon = [UIImage imageNamed:@"empty-thread-tag"];
            }
        }
        cell.secondaryIcon = [[AwfulThreadTags sharedThreadTags]
                              threadTagNamed:thread.secondIconName];
        if (thread.secondIconName && !cell.secondaryIcon) {
            [self updateThreadTagsForCellAtIndexPath:indexPath];
        }
        if (thread.isStickyValue) {
            cell.stickyImageView.hidden = NO;
            cell.stickyImageView.image = [UIImage imageNamed:@"sticky.png"];
        } else {
            cell.stickyImageView.hidden = YES;
        }
        // Hardcode Film Dump to never show ratings; its thread tags are the ratings.
        if ([thread.forum.forumID isEqualToString:@"133"]) {
            cell.rating = 0;
        } else {
            cell.rating = [thread.threadRating floatValue];
        }
    } else {
        cell.icon = nil;
        cell.secondaryIcon = nil;
        cell.stickyImageView.hidden = YES;
        cell.closed = thread.isClosedValue;
        cell.rating = 0;
    }
    cell.textLabel.text = [thread.title stringByCollapsingWhitespace];
    if (thread.isStickyValue || !thread.isClosedValue) {
        cell.iconAlpha = 1;
        cell.ratingImageView.alpha = 1;
        cell.textLabel.textColor = [AwfulTheme currentTheme].threadCellTextColor;
    } else {
        cell.iconAlpha = 0.5;
        cell.ratingImageView.alpha = 0.5;
        cell.textLabel.textColor = [AwfulTheme currentTheme].threadCellClosedThreadColor;
    }
    NSNumberFormatterStyle numberStyle = NSNumberFormatterDecimalStyle;
    NSString *pagesFormatted = [NSNumberFormatter localizedStringFromNumber:thread.numberOfPages
                                                                numberStyle:numberStyle];
    NSString *plural = thread.numberOfPagesValue == 1 ? @"" : @"s";
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ page%@", pagesFormatted, plural];
    cell.detailTextLabel.textColor = [AwfulTheme currentTheme].threadCellPagesTextColor;
    if (thread.beenSeen) {
        cell.originalPosterTextLabel.text = [NSString stringWithFormat:@"Killed by %@",
                                             thread.lastPostAuthorName];
    } else {
        cell.originalPosterTextLabel.text = [NSString stringWithFormat:@"Posted by %@",
                                             thread.author.username];
    }
    AwfulTheme *theme = [AwfulTheme currentTheme];
    cell.originalPosterTextLabel.textColor = theme.threadCellOriginalPosterTextColor;
    if (thread.starCategoryValue == AwfulStarCategoryRed) {
        cell.unreadCountBadgeView.badgeColor = theme.threadListUnreadBadgeRedColor;
        cell.unreadCountBadgeView.offBadgeColor = theme.threadListUnreadBadgeRedOffColor;
    } else if (thread.starCategoryValue == AwfulStarCategoryYellow) {
        cell.unreadCountBadgeView.badgeColor = theme.threadListUnreadBadgeYellowColor;
        cell.unreadCountBadgeView.offBadgeColor = theme.threadListUnreadBadgeYellowOffColor;
    } else if (thread.starCategoryValue == AwfulStarCategoryOrange) {
        cell.unreadCountBadgeView.badgeColor = theme.threadListUnreadBadgeOrangeColor;
        cell.unreadCountBadgeView.offBadgeColor = theme.threadListUnreadBadgeOrangeOffColor;
    } else {
        cell.unreadCountBadgeView.badgeColor = theme.threadListUnreadBadgeBlueColor;
        cell.unreadCountBadgeView.offBadgeColor = theme.threadListUnreadBadgeBlueOffColor;
    }
    cell.unreadCountBadgeView.highlightedBadgeColor = theme.threadListUnreadBadgeHighlightedColor;
    NSInteger unreadPosts = thread.totalRepliesValue + 1 - thread.seenPostsValue;
    cell.unreadCountBadgeView.badgeText = [@(unreadPosts) stringValue];
    cell.unreadCountBadgeView.on = unreadPosts > 0;
    cell.showsUnread = thread.seenPostsValue > 0;
    cell.backgroundColor = theme.threadCellBackgroundColor;
    cell.selectionStyle = theme.cellSelectionStyle;
    AwfulDisclosureIndicatorView *disclosure = (AwfulDisclosureIndicatorView *)cell.accessoryView;
    disclosure.color = theme.disclosureIndicatorColor;
    disclosure.highlightedColor = theme.disclosureIndicatorHighlightedColor;
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

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.backgroundColor = [AwfulTheme currentTheme].threadCellBackgroundColor;
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
    page.thread = [AwfulThread firstOrNewThreadWithThreadID:threadID];
    [page loadPage:1 singleUserID:nil];
    [self displayPage:page];
}

- (void)threadComposeControllerDidCancel:(AwfulThreadComposeViewController *)controller
{
    // TODO save draft?
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
