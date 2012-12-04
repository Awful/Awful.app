//
//  AwfulThreadListController.m
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulThreadListController.h"
#import "AwfulFetchedTableViewControllerSubclass.h"
#import "AwfulActionSheet.h"
#import "AwfulAlertView.h"
#import "AwfulDataStack.h"
#import "AwfulHTTPClient.h"
#import "AwfulLoginController.h"
#import "AwfulModels.h"
#import "AwfulPostsViewController.h"
#import "AwfulSettings.h"
#import "AwfulSplitViewController.h"
#import "AwfulTheme.h"
#import "AwfulThreadCell.h"
#import "AwfulThreadTags.h"
#import "NSString+CollapseWhitespace.h"
#import "SVPullToRefresh.h"
#import "UIViewController+NavigationEnclosure.h"

typedef enum {
    AwfulThreadListActionsTypeFirstPage = 0,
    AwfulThreadListActionsTypeLastPage,
    AwfulThreadListActionsTypeUnread
} AwfulThreadListActionsType;


@interface AwfulThreadListController ()

@property (nonatomic) NSMutableDictionary *cellsWithoutThreadTags;

@property (nonatomic) BOOL listeningForNewThreadTags;

@end


@implementation AwfulThreadListController

- (id)init
{
    self = [super init];
    if (!(self = [super init])) return nil;
    _cellsWithoutThreadTags = [NSMutableDictionary new];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(settingsChanged:)
                                                 name:AwfulSettingsDidChangeNotification
                                               object:nil];
    return self;
}

- (void)dealloc
{
    NSNotificationCenter *noteCenter = [NSNotificationCenter defaultCenter];
    [noteCenter removeObserver:self name:AwfulSettingsDidChangeNotification object:nil];
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
    _forum = forum;
    self.title = _forum.name;
    self.navigationItem.backBarButtonItem = [self abbreviatedBackBarButtonItem];
    self.fetchedResultsController = [self createFetchedResultsController];
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

#pragma mark - Table view controller

- (void)refresh
{
    [super refresh];
    [self.cellsWithoutThreadTags removeAllObjects];
    [self loadPageNum:1];
    CGFloat refreshViewHeight = self.tableView.pullToRefreshView.bounds.size.height;
    [self.tableView setContentOffset:CGPointMake(0, -refreshViewHeight)];
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
    id op = [[AwfulHTTPClient client] listThreadsInForumWithID:self.forum.forumID
                                                        onPage:pageNum
                                                       andThen:^(NSError *error, NSArray *threads)
    {
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
}

- (void)showThreadActionsForThread:(AwfulThread *)thread
{
    AwfulActionSheet *sheet = [AwfulActionSheet new];
    sheet.title = [thread.title stringByCollapsingWhitespace];
    [sheet addButtonWithTitle:@"Jump to First Page" block:^{
        AwfulPostsViewController *page = [AwfulPostsViewController new];
        page.thread = thread;
        [self displayPage:page];
        [page loadPage:1];
    }];
    [sheet addButtonWithTitle:@"Jump to Last Page" block:^{
        AwfulPostsViewController *page = [AwfulPostsViewController new];
        page.thread = thread;
        [self displayPage:page];
        [page loadPage:AwfulPageLast];
    }];
    [sheet addButtonWithTitle:@"Mark as Unread" block:^{
        [self markThreadUnseen:thread];
    }];
    [sheet addCancelButtonWithTitle:@"Cancel"];
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [sheet showFromTabBar:self.tabBarController.tabBar];
    } else if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        NSUInteger index = [self.fetchedResultsController.fetchedObjects indexOfObject:thread];
        if (index != NSNotFound) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:index inSection:0];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
            [sheet showFromRect:cell.frame inView:self.tableView animated:YES];
        }
    }
}

- (void)markThreadUnseen:(AwfulThread *)thread
{
    [[AwfulHTTPClient client] forgetReadPostsInThreadWithID:thread.threadID
                                                    andThen:^(NSError *error)
    {
        if (error) {
            [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
        } else {
            thread.totalUnreadPostsValue = -1;
            thread.seenValue = NO;
            [[AwfulDataStack sharedDataStack] save];
        }
    }];
}

- (void)displayPage:(AwfulPostsViewController *)page
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [self.navigationController pushViewController:page animated:YES];
    } else if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        NSMutableArray *vcs = [NSMutableArray arrayWithArray:self.splitViewController.viewControllers];
        [vcs removeLastObject];
        
        [vcs addObject:[page enclosingNavigationController]];
        self.splitViewController.viewControllers = vcs;
    }
}

- (void)pop
{
    [self.navigationController popViewControllerAnimated:YES];
}

#pragma mark - Table view data source and delegate

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * const Identifier = @"AwfulThreadCell";
    AwfulThreadCell *cell = [tableView dequeueReusableCellWithIdentifier:Identifier];
    if (!cell) {
        cell = [[AwfulThreadCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:Identifier];
        UILongPressGestureRecognizer *longPress = [UILongPressGestureRecognizer new];
        [longPress addTarget:self action:@selector(showThreadActions:)];
        [cell addGestureRecognizer:longPress];
    }
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(UITableViewCell *)genericCell atIndexPath:(NSIndexPath *)indexPath
{
    AwfulThreadCell *cell = (AwfulThreadCell *)genericCell;
    AwfulThread *thread = [self.fetchedResultsController objectAtIndexPath:indexPath];
    if ([AwfulSettings settings].showThreadTags) {
        cell.imageView.hidden = NO;
        cell.imageView.image = [[AwfulThreadTags sharedThreadTags]
                                threadTagNamed:thread.firstIconName];
        if (!cell.imageView.image) {
            [self updateThreadTag:thread.firstIconName forCellAtIndexPath:indexPath];
        }
        cell.secondaryTagImageView.hidden = NO;
        cell.secondaryTagImageView.image = [[AwfulThreadTags sharedThreadTags]
                                            threadTagNamed:thread.secondIconName];
        if (thread.secondIconName && !cell.secondaryTagImageView.image) {
            [self updateThreadTag:thread.secondIconName forCellAtIndexPath:indexPath];
        }
        cell.sticky = thread.isStickyValue;
        // Hardcode Film Dump to never show ratings; its thread tags are the ratings.
        if ([thread.forum.forumID isEqualToString:@"133"]) {
            cell.rating = 0;
        } else {
            cell.rating = [thread.threadRating floatValue];
        }
    } else {
        cell.imageView.image = nil;
        cell.imageView.hidden = YES;
        cell.secondaryTagImageView.image = nil;
        cell.secondaryTagImageView.hidden = YES;
        cell.sticky = NO;
        cell.closed = thread.isClosedValue;
        cell.rating = 0;
    }
    cell.textLabel.text = [thread.title stringByCollapsingWhitespace];
    if (thread.canReply) {
        cell.textLabel.textColor = [AwfulTheme currentTheme].threadCellTextColor;
    } else {
        cell.textLabel.textColor = [AwfulTheme currentTheme].threadCellLockedThreadColor;
    }
    NSNumberFormatterStyle numberStyle = NSNumberFormatterDecimalStyle;
    NSString *pagesFormatted = [NSNumberFormatter localizedStringFromNumber:thread.numberOfPages
                                                                numberStyle:numberStyle];
    NSString *plural = thread.numberOfPagesValue == 1 ? @"" : @"s";
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ page%@", pagesFormatted, plural];
    cell.detailTextLabel.textColor = [AwfulTheme currentTheme].threadCellPagesTextColor;
    if (thread.seenValue) {
        cell.originalPosterTextLabel.text = [NSString stringWithFormat:@"Killed by %@",
                                             thread.lastPostAuthorName];
    } else {
        cell.originalPosterTextLabel.text = [NSString stringWithFormat:@"Posted by %@",
                                             thread.authorName];
    }
    AwfulTheme *theme = [AwfulTheme currentTheme];
    cell.originalPosterTextLabel.textColor = theme.threadCellOriginalPosterTextColor;
    if (thread.starCategoryValue == AwfulStarCategoryRed) {
        cell.unreadCountBadgeView.badgeColor = theme.threadListUnreadBadgeRedColor;
        cell.unreadCountBadgeView.offBadgeColor = theme.threadListUnreadBadgeRedOffColor;
    } else if (thread.starCategoryValue == AwfulStarCategoryYellow) {
        cell.unreadCountBadgeView.badgeColor = theme.threadListUnreadBadgeYellowColor;
        cell.unreadCountBadgeView.offBadgeColor = theme.threadListUnreadBadgeYellowOffColor;
    } else {
        cell.unreadCountBadgeView.badgeColor = theme.threadListUnreadBadgeBlueColor;
        cell.unreadCountBadgeView.offBadgeColor = theme.threadListUnreadBadgeBlueOffColor;
    }
    cell.unreadCountBadgeView.highlightedBadgeColor = theme.threadListUnreadBadgeHighlightedColor;
    cell.unreadCountBadgeView.badgeText = [thread.totalUnreadPosts stringValue];
    cell.unreadCountBadgeView.on = thread.totalUnreadPostsValue > 0;
    cell.showsUnread = thread.totalUnreadPostsValue != -1;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    cell.backgroundColor = theme.threadCellBackgroundColor;
    cell.selectionStyle = [AwfulTheme currentTheme].cellSelectionStyle;
}

- (void)updateThreadTag:(NSString *)threadTagName forCellAtIndexPath:(NSIndexPath *)indexPath
{
    if (!self.cellsWithoutThreadTags[indexPath]) {
        self.cellsWithoutThreadTags[indexPath] = [NSMutableArray new];
    }
    [self.cellsWithoutThreadTags[indexPath] addObject:threadTagName];
    if (self.listeningForNewThreadTags) return;
    self.listeningForNewThreadTags = YES;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(newThreadTags:)
                                                 name:AwfulNewThreadTagsAvailableNotification
                                               object:nil];
}

- (void)newThreadTags:(NSNotification *)note
{
    NSMutableArray *updated = [NSMutableArray new];
    for (NSIndexPath *indexPath in self.cellsWithoutThreadTags) {
        NSMutableArray *listOfTags = self.cellsWithoutThreadTags[indexPath];
        for (NSString *tag in [listOfTags copy]) {
            UIImage *image = [[AwfulThreadTags sharedThreadTags] threadTagNamed:tag];
            if (!image) continue;
            UITableViewCell *genericCell = [self.tableView cellForRowAtIndexPath:indexPath];
            AwfulThreadCell *cell = (AwfulThreadCell *)genericCell;
            AwfulThread *thread = [self.fetchedResultsController objectAtIndexPath:indexPath];
            if ([tag isEqualToString:thread.firstIconName]) {
                cell.imageView.image = image;
            } else if ([tag isEqualToString:thread.secondIconName]) {
                cell.secondaryTagImageView.image = image;
            }
            [updated addObject:indexPath];
            [listOfTags removeObject:tag];
        }
    }
    [self.tableView reloadRowsAtIndexPaths:updated withRowAnimation:UITableViewRowAnimationNone];
    for (id key in updated) {
        if ([self.cellsWithoutThreadTags[key] count] == 0) {
            [self.cellsWithoutThreadTags removeObjectForKey:key];
        }
    }
    if ([self.cellsWithoutThreadTags count] == 0) {
        self.listeningForNewThreadTags = NO;
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:AwfulNewThreadTagsAvailableNotification
                                                      object:nil];
    }
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
    return (thread.totalUnreadPostsValue >= 0);
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
    [page loadPage:thread.seenValue ? AwfulPageNextUnread : 1];
    if (self.splitViewController) {
        UINavigationController *nav = self.splitViewController.viewControllers[1];
        [nav setViewControllers:@[page] animated:YES];
        AwfulSplitViewController *split = (AwfulSplitViewController *)self.splitViewController;
        [split.masterPopoverController dismissPopoverAnimated:YES];
        [self.tableView deselectRowAtIndexPath:self.tableView.indexPathForSelectedRow
                                      animated:YES];
    } else {
        [self.navigationController pushViewController:page animated:YES];
    }
}

@end
