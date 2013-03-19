//
//  AwfulForumsListController.m
//  Awful
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulForumsListController.h"
#import "AwfulFetchedTableViewControllerSubclass.h"
#import "AwfulAlertView.h"
#import "AwfulDataStack.h"
#import "AwfulDisclosureIndicatorView.h"
#import "AwfulForumCell.h"
#import "AwfulHTTPClient.h"
#import "AwfulModels.h"
#import "AwfulLepersViewController.h"
#import "AwfulLoginController.h"
#import "AwfulSettings.h"
#import "AwfulTheme.h"
#import "AwfulThreadListController.h"
#import "NSManagedObject+Awful.h"

@interface AwfulForumsListController ()

@property (nonatomic) NSDate *lastRefresh;

@property (nonatomic) NSMutableArray *favoriteForums;

@end


@interface AwfulForumHeader : UILabel @end

@implementation AwfulForumHeader

- (void)drawTextInRect:(CGRect)rect
{
    [super drawTextInRect:CGRectInset(rect, 10, 0)];
}

@end


@implementation AwfulForumsListController

- (id)init
{
    if (!(self = [super initWithStyle:UITableViewStylePlain])) return nil;
    self.title = @"Forums";
    self.tabBarItem.image = [UIImage imageNamed:@"list_icon.png"];
    _favoriteForums = [NSMutableArray new];
    [_favoriteForums addObjectsFromArray:[AwfulSettings settings].favoriteForums ?: @[]];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsDidChange:)
                                                 name:AwfulSettingsDidChangeNotification object:nil];
    return self;
}

- (void)settingsDidChange:(NSNotification *)note
{
    if (self.userDrivenChange) return;
    NSArray *changedSettings = note.userInfo[AwfulSettingsDidChangeSettingsKey];
    if (![changedSettings containsObject:AwfulSettingsKeys.favoriteForums]) return;
    [self.favoriteForums removeAllObjects];
    [self.favoriteForums addObjectsFromArray:[AwfulSettings settings].favoriteForums];
    [self.tableView reloadData];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSFetchedResultsController *)createFetchedResultsController
{
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:[AwfulForum entityName]];
    request.predicate = [NSPredicate predicateWithFormat:@"parentForum == nil or parentForum.expanded == YES"];
    request.sortDescriptors = @[
        [NSSortDescriptor sortDescriptorWithKey:@"category.index" ascending:YES],
        [NSSortDescriptor sortDescriptorWithKey:@"index" ascending:YES]
    ];
    return [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                               managedObjectContext:[AwfulDataStack sharedDataStack].context
                                                 sectionNameKeyPath:@"category.index"
                                                          cacheName:nil];
}

- (NSDate *)lastRefresh
{
    return [[NSUserDefaults standardUserDefaults] objectForKey:kLastRefreshDate];
}

- (void)setLastRefresh:(NSDate *)lastRefresh
{
    [[NSUserDefaults standardUserDefaults] setObject:lastRefresh forKey:kLastRefreshDate];
}

NSString * const kLastRefreshDate = @"com.awfulapp.Awful.LastForumRefreshDate";

- (void)toggleFavorite:(UIButton *)button
{
    button.selected = !button.selected;
    UIView *cell = button.superview;
    while (cell && ![cell isKindOfClass:[UITableViewCell class]]) cell = cell.superview;
    if (!cell) return;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:(UITableViewCell *)cell];
    AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    if (button.selected) {
        [self.favoriteForums addObject:forum.forumID];
    } else {
        [self.favoriteForums removeObject:forum.forumID];
    }
    self.userDrivenChange = YES;
    [AwfulSettings settings].favoriteForums = self.favoriteForums;
    self.userDrivenChange = NO;
}

- (void)toggleExpanded:(UIButton *)button
{
    button.selected = !button.selected;
    UIView *cell = button.superview;
    while (cell && ![cell isKindOfClass:[UITableViewCell class]]) cell = cell.superview;
    if (!cell) return;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:(UITableViewCell *)cell];
    AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    if (button.selected) {
        forum.expandedValue = YES;
    } else {
        RecursivelyCollapseForum(forum);
    }
    [[AwfulDataStack sharedDataStack] save];
    
    // The fetched results controller won't pick up on changes to the keypath "parentForum.expanded"
    // for forums that should be newly visible (dunno why) so we need to help it along.
    for (AwfulForum *child in forum.children) {
        [child willChangeValueForKey:AwfulForumRelationships.parentForum];
        [child didChangeValueForKey:AwfulForumRelationships.parentForum];
    }
}

static void RecursivelyCollapseForum(AwfulForum *forum)
{
    forum.expandedValue = NO;
    for (AwfulForum *child in forum.children) {
        RecursivelyCollapseForum(child);
    }
}

- (void)setCellImagesForCell:(AwfulForumCell *)cell
{
    if (!cell) return;
    [cell.expandButton setImage:[AwfulTheme currentTheme].forumCellExpandButtonNormalImage
                       forState:UIControlStateNormal];
    [cell.expandButton setImage:[AwfulTheme currentTheme].forumCellExpandButtonSelectedImage
                       forState:UIControlStateSelected];
    [cell.favoriteButton setImage:[AwfulTheme currentTheme].forumCellFavoriteButtonNormalImage
                         forState:UIControlStateNormal];
    [cell.favoriteButton setImage:[AwfulTheme currentTheme].forumCellFavoriteButtonSelectedImage
                         forState:UIControlStateSelected];
}

#pragma mark - AwfulTableViewController

- (void)refresh
{
    [super refresh];
    [self.networkOperation cancel];
    __block id op;
    op = [[AwfulHTTPClient client] listForumsAndThen:^(NSError *error, NSArray *forums)
    {
        if (![self.networkOperation isEqual:op]) return;
        if (error) {
            [AwfulAlertView showWithTitle:@"Network Error" error:error buttonTitle:@"OK"];
        } else {
            self.lastRefresh = [NSDate date];
        }
        self.refreshing = NO;
    }];
    self.networkOperation = op;
}

- (BOOL)canPullToRefresh
{
    return NO;
}

- (BOOL)refreshOnAppear
{
    if (![AwfulHTTPClient client].loggedIn) return NO;
    if (![AwfulHTTPClient client].reachable) return NO;
    if (!self.lastRefresh) return YES;
    if ([[NSDate date] timeIntervalSinceDate:self.lastRefresh] > 60 * 60 * 6) return YES;
    if ([self.fetchedResultsController.fetchedObjects count] == 0) return YES;
    if ([AwfulForum firstMatchingPredicate:@"index = -1"]) return YES;
    return NO;
}

- (void)retheme
{
    [super retheme];
    self.tableView.separatorColor = [AwfulTheme currentTheme].forumListSeparatorColor;
    self.view.backgroundColor = [AwfulTheme currentTheme].forumListBackgroundColor;
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.rowHeight = 50;
    self.tableView.sectionHeaderHeight = 26;
    self.tableView.backgroundView = nil;
    
    // This little ditty stops section headers from sticking.
    CGRect headerFrame = (CGRect){ .size.height = self.tableView.rowHeight };
    self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:headerFrame];
    self.tableView.contentInset = (UIEdgeInsets){ .top = -self.tableView.rowHeight };
    
    // Don't show cell separators after last cell.
    self.tableView.tableFooterView = [UIView new];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if ([self.tableView numberOfSections] <= 1) [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

// Leper's Colony is shown as a pseudo-forum in its own section (the last section).

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSInteger lepersColony = [AwfulHTTPClient client].isLoggedIn ? 1 : 0;
    return [super numberOfSectionsInTableView:tableView] + lepersColony;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if ([AwfulHTTPClient client].isLoggedIn && section + 1 == [tableView numberOfSections]) {
        return 1;
    }
    return [super tableView:tableView numberOfRowsInSection:section];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UILabel *header = [AwfulForumHeader new];
    header.frame = (CGRect){ .size = { tableView.bounds.size.width, tableView.rowHeight } };
    header.font = [UIFont boldSystemFontOfSize:15];
    header.textColor = [AwfulTheme currentTheme].forumListHeaderTextColor;
    header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    header.backgroundColor = [AwfulTheme currentTheme].forumListHeaderBackgroundColor;
    if ([AwfulHTTPClient client].isLoggedIn && section + 1 == [tableView numberOfSections]) {
        header.text = @"Awful";
    } else {
        AwfulForum *anyForum = [[self.fetchedResultsController.sections[section] objects] lastObject];
        header.text = anyForum.category.name;
    }
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return tableView.sectionHeaderHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * const Identifier = @"ForumCell";
    AwfulForumCell *cell = [tableView dequeueReusableCellWithIdentifier:Identifier];
    if (!cell) {
        cell = [[AwfulForumCell alloc] initWithReuseIdentifier:Identifier];
        cell.accessoryView = [AwfulDisclosureIndicatorView new];
        [cell.expandButton addTarget:self
                              action:@selector(toggleExpanded:)
                    forControlEvents:UIControlEventTouchUpInside];
        [cell.favoriteButton addTarget:self
                                action:@selector(toggleFavorite:)
                      forControlEvents:UIControlEventTouchUpInside];
    }
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(UITableViewCell *)plainCell atIndexPath:(NSIndexPath*)indexPath
{
    AwfulForumCell *cell = (AwfulForumCell *)plainCell;
    cell.textLabel.textColor = [AwfulTheme currentTheme].forumCellTextColor;
    cell.selectionStyle = [AwfulTheme currentTheme].cellSelectionStyle;
    AwfulDisclosureIndicatorView *disclosure = (AwfulDisclosureIndicatorView *)cell.accessoryView;
    disclosure.color = [AwfulTheme currentTheme].disclosureIndicatorColor;
    disclosure.highlightedColor = [AwfulTheme currentTheme].disclosureIndicatorHighlightedColor;
    if ([AwfulHTTPClient client].isLoggedIn && indexPath.section + 1 == [self.tableView numberOfSections]) {
        cell.textLabel.text = @"Leper's Colony";
        cell.showsFavorite = NO;
        cell.showsExpanded = AwfulForumCellShowsExpandedLeavesRoom;
    } else {
        AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
        cell.textLabel.text = forum.name;
        [self setCellImagesForCell:cell];
        cell.showsFavorite = YES;
        cell.favorite = [self.favoriteForums containsObject:forum.forumID];
        cell.expanded = forum.expandedValue;
        if ([forum.children count]) {
            cell.showsExpanded = AwfulForumCellShowsExpandedButton;
        } else {
            cell.showsExpanded = AwfulForumCellShowsExpandedLeavesRoom;
        }
    }
}

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([AwfulHTTPClient client].isLoggedIn && indexPath.section + 1 == [tableView numberOfSections]) {
        cell.backgroundColor = [AwfulTheme currentTheme].forumCellBackgroundColor;
    } else {
        AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
        if (forum.parentForum) {
            cell.backgroundColor = [AwfulTheme currentTheme].forumCellSubforumBackgroundColor;
        } else {
            cell.backgroundColor = [AwfulTheme currentTheme].forumCellBackgroundColor;
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([AwfulHTTPClient client].isLoggedIn && indexPath.section + 1 == [tableView numberOfSections]) {
        AwfulLepersViewController *lepersColony = [AwfulLepersViewController new];
        [self.navigationController pushViewController:lepersColony animated:YES];
    } else {
        AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
        AwfulThreadListController *threadList = [AwfulThreadListController new];
        threadList.forum = forum;
        [self.navigationController pushViewController:threadList animated:YES];
    }
}

@end

