//  ForumListViewController.m
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "ForumListViewController.h"
#import <AFNetworking/AFNetworking.h>
#import "AwfulAlertView.h"
#import "AwfulAppDelegate.h"
#import "AwfulFavoriteForumCell.h"
#import "AwfulForumCell.h"
#import "ThreadListViewController.h"
#import "AwfulForumTreeDataSource.h"
#import "AwfulForumsClient.h"
#import "AwfulFrameworkCategories.h"
#import "AwfulModels.h"
#import "AwfulRefreshMinder.h"
#import "AwfulSettings.h"

@interface ForumListViewController () <AwfulForumTreeDataSourceDelegate>

@property (nonatomic) NSMutableArray *favoriteForums;
@property (nonatomic) BOOL userDrivenChange;

@end

@implementation ForumListViewController
{
    AwfulForumTreeDataSource *_treeDataSource;
    BOOL _observingReachability;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    if (!(self = [super initWithStyle:UITableViewStylePlain])) return nil;
    _managedObjectContext = managedObjectContext;
    _favoriteForums = [[self fetchFavoriteForumsWithIDsFromSettings] mutableCopy];
    
    self.title = @"Forums";
    self.navigationItem.backBarButtonItem = [UIBarButtonItem awful_emptyBackBarButtonItem];
    self.tabBarItem.accessibilityLabel = @"Forums list";
    self.tabBarItem.image = [UIImage imageNamed:@"list_icon"];
    [self showOrHideEditButton];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsDidChange:) name:AwfulSettingsDidChangeNotification object:nil];
    return self;
}

- (id)initWithStyle:(UITableViewStyle)style
{
    return [self initWithManagedObjectContext:nil];
}

- (NSArray *)fetchFavoriteForumsWithIDsFromSettings
{
    NSArray *forumIDs = [AwfulSettings sharedSettings].favoriteForums;
    if (forumIDs.count == 0) {
        return @[];
    }
    NSArray *favoriteForums = [AwfulForum fetchAllInManagedObjectContext:self.managedObjectContext
                                                 matchingPredicateFormat:@"forumID IN %@", forumIDs];
    return [favoriteForums sortedArrayUsingComparator:^(AwfulForum *a, AwfulForum *b) {
        return [@([forumIDs indexOfObject:a.forumID]) compare:@([forumIDs indexOfObject:b.forumID])];
    }];
}

- (void)settingsDidChange:(NSNotification *)note
{
    if (self.userDrivenChange) return;
    
    NSString *changedSetting = note.userInfo[AwfulSettingsDidChangeSettingKey];
    if ([changedSetting isEqualToString:AwfulSettingsKeys.favoriteForums]) {
        [self.favoriteForums setArray:[self fetchFavoriteForumsWithIDsFromSettings]];
        [self showOrHideEditButton];
        [self.tableView reloadData];
    }
}

- (void)loadView
{
    [super loadView];
    [self.tableView registerClass:[UITableViewHeaderFooterView class] forHeaderFooterViewReuseIdentifier:HeaderIdentifier];
    [self.tableView registerClass:[AwfulForumCell class] forCellReuseIdentifier:ForumCellIdentifier];
    [self.tableView registerClass:[AwfulFavoriteForumCell class] forCellReuseIdentifier:FavoriteCellIdentifier];
    self.tableView.restorationIdentifier = @"Forum list";
}

static NSString * const HeaderIdentifier = @"Header";
static NSString * const ForumCellIdentifier = @"Forum";
static NSString * const FavoriteCellIdentifier = @"Favorite";

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.rowHeight = 45;
    self.tableView.backgroundView = nil;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 37, 0, 0);
    [self.tableView awful_unstickSectionHeaders];
    [self.tableView awful_hideExtraneousSeparators];
    _treeDataSource = [[AwfulForumTreeDataSource alloc] initWithTableView:self.tableView reuseIdentifier:ForumCellIdentifier];
    _treeDataSource.topDataSource = self;
    _treeDataSource.managedObjectContext = self.managedObjectContext;
    _treeDataSource.delegate = self;
}

- (void)showOrHideEditButton
{
    UIBarButtonItem *item = self.favoriteForums.count > 0 ? self.editButtonItem : nil;
    [self.navigationItem setRightBarButtonItem:item animated:YES];
}

- (void)toggleFavorite:(UIButton *)button
{
    // Figure out which forum is represented by the tapped button's cell.
    AwfulForum *forum;
    UIView *cell = button.superview;
    while (cell && ![cell isKindOfClass:[UITableViewCell class]]) {
        cell = cell.superview;
    }
    if (!cell) return;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:(UITableViewCell *)cell];
    if (self.favoriteForums.count > 0 && indexPath.section == 0) {
        forum = self.favoriteForums[indexPath.row];
    } else {
        forum = [_treeDataSource forumAtIndexPath:indexPath];
    }
    BOOL isFavorite = [self.favoriteForums containsObject:forum];
    
    [self.tableView beginUpdates];
    
    [_treeDataSource reloadRowWithForum:forum];
    
    if (isFavorite) {
        NSInteger row = [self.favoriteForums indexOfObject:forum];
        [self.favoriteForums removeObjectAtIndex:row];
        if (self.favoriteForums.count == 0) {
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationTop];
            [self showOrHideEditButton];
            self.editing = NO;
        } else {
            NSIndexPath *oldRowPath = [NSIndexPath indexPathForRow:row inSection:0];
            [self.tableView deleteRowsAtIndexPaths:@[ oldRowPath ] withRowAnimation:UITableViewRowAnimationTop];
        }
    } else {
        [self.favoriteForums addObject:forum];
        if (self.favoriteForums.count == 1) {
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationTop];
            [self showOrHideEditButton];
        } else {
            NSIndexPath *newRowPath = [NSIndexPath indexPathForRow:(self.favoriteForums.count - 1) inSection:0];
            [self.tableView insertRowsAtIndexPaths:@[ newRowPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }
    
    [self.tableView endUpdates];
    
    [self saveFavoriteForumsToSettings];
}

- (void)toggleExpanded:(UIButton *)button
{
    button.selected = !button.selected;
    UIView *cell = button.superview;
    while (cell && ![cell isKindOfClass:[UITableViewCell class]]) {
        cell = cell.superview;
    }
    if (!cell) return;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:(UITableViewCell *)cell];
    AwfulForum *forum = [_treeDataSource forumAtIndexPath:indexPath];
    [_treeDataSource setForum:forum childrenExpanded:button.selected];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    _treeDataSource.updatesTableView = YES;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self refreshIfNecessary];
}

- (void)refreshIfNecessary
{
    if (![AwfulForumsClient client].loggedIn) return;
    
    if ([[AwfulRefreshMinder minder] shouldRefreshForumList] || self.tableView.numberOfSections < 2 ||
        [AwfulForum anyInManagedObjectContext:self.managedObjectContext matchingPredicateFormat:@"index = -1"]) {
        if ([AwfulForumsClient client].reachable) {
            [self refresh];
        } else {
            [self refreshOnceServerIsReachable];
        }
    }
}

- (void)refresh
{
    [[AwfulForumsClient client] taxonomizeForumsAndThen:^(NSError *error, NSArray *categories) {
        if (!error) {
            [[AwfulRefreshMinder minder] didFinishRefreshingForumList];
        }
    }];
}

- (void)refreshOnceServerIsReachable
{
    if (_observingReachability) return;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:AFNetworkingReachabilityDidChangeNotification
                                               object:nil];
    _observingReachability = YES;

}

- (void)reachabilityChanged:(NSNotification *)note
{
    [self stopObservingReachability];
    [self refresh];
}

- (void)stopObservingReachability
{
    if (!_observingReachability) return;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:AFNetworkingReachabilityDidChangeNotification object:nil];
    _observingReachability = NO;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    _treeDataSource.updatesTableView = NO;
}

- (void)showForum:(AwfulForum *)forum animated:(BOOL)animated
{
    ThreadListViewController *threadList = [[ThreadListViewController alloc] initWithForum:forum];
    threadList.restorationClass = threadList.class;
    threadList.restorationIdentifier = @"Thread";
    [self.navigationController pushViewController:threadList animated:animated];
}

- (void)saveFavoriteForumsToSettings
{
    self.userDrivenChange = YES;
    [AwfulSettings sharedSettings].favoriteForums = [self.favoriteForums valueForKey:@"forumID"];
    self.userDrivenChange = NO;
}

#pragma mark - UITableViewDataSource

// AwfulForumsListController works in concert with an AwfulForumTreeDataSource, setting itself as the tree data source's topDataSource. As such, we only need to handle the UITableViewDataSource methods for the section we control: section 0, "Favorites".

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (self.favoriteForums.count > 0) {
        return 1;
    }
    return 0;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.favoriteForums.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulFavoriteForumCell *cell = [tableView dequeueReusableCellWithIdentifier:FavoriteCellIdentifier forIndexPath:indexPath];
    AwfulForum *forum = self.favoriteForums[indexPath.row];
    cell.textLabel.text = forum.name;
    cell.separatorInset = UIEdgeInsetsZero;
    ThemeCell(self.theme, cell);
    return cell;
}

static void ThemeCell(AwfulTheme *theme, UITableViewCell *cell)
{
    cell.backgroundColor = theme[@"listBackgroundColor"];
	cell.textLabel.textColor = theme[@"listTextColor"];
    UIView *selectedBackgroundView = [UIView new];
    selectedBackgroundView.backgroundColor = theme[@"listSelectedBackgroundColor"];
    cell.selectedBackgroundView = selectedBackgroundView;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)favoriteIndexPath
{
    AwfulForum *forum = self.favoriteForums[favoriteIndexPath.row];
    
    // Let's delete the favorite row and update the forum's proper row in one fell swoop. To do so, we need the forum's index path before any potential deletion of the favorites section (in model or in view).
    NSIndexPath *forumIndexPath = [_treeDataSource indexPathForForum:forum];
    
    // Now it's safe to update the array of favorite forums.
    [self.favoriteForums removeObjectAtIndex:favoriteIndexPath.row];
    
    [tableView beginUpdates];
    
    if (self.favoriteForums.count == 0) {
        [tableView deleteSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationTop];
        [self showOrHideEditButton];
        self.editing = NO;
    } else {
        [tableView deleteRowsAtIndexPaths:@[ favoriteIndexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    if (forumIndexPath) {
        [tableView reloadRowsAtIndexPaths:@[ forumIndexPath ] withRowAnimation:UITableViewRowAnimationNone];
    }
    
    [tableView endUpdates];
    
    [self saveFavoriteForumsToSettings];
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    id forum = self.favoriteForums[sourceIndexPath.row];
    [self.favoriteForums removeObjectAtIndex:sourceIndexPath.row];
    [self.favoriteForums insertObject:forum atIndex:destinationIndexPath.row];
    [self saveFavoriteForumsToSettings];
}

#pragma mark - UITableViewDelegate

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UITableViewHeaderFooterView *header = [tableView dequeueReusableHeaderFooterViewWithIdentifier:HeaderIdentifier];
    header.textLabel.textColor = self.theme[@"listHeaderTextColor"];
    header.contentView.backgroundColor = self.theme[@"listHeaderBackgroundColor"];
    if (self.favoriteForums.count > 0 && section == 0) {
        header.textLabel.text = @"Favorites";
    } else {
        header.textLabel.text = [_treeDataSource categoryNameAtIndex:section];
    }
    return header;
}

- (void)tableView:(UITableView *)tableView
willDisplayHeaderView:(UITableViewHeaderFooterView *)header
       forSection:(NSInteger)section
{
    // For some unknown reason, this needs to happen here.
    header.textLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleBody];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 36;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulForum *forum;
    if (self.favoriteForums.count > 0 && indexPath.section == 0) {
        forum = self.favoriteForums[indexPath.row];
    } else {
        forum = [_treeDataSource forumAtIndexPath:indexPath];
    }
    [self showForum:forum animated:YES];
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return @"Unstar";
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    return self.favoriteForums.count > 0 && indexPath.section == 0;
}

- (NSIndexPath *)tableView:(UITableView *)tableView
targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath
       toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath
{
    if (proposedDestinationIndexPath.section == 0) return proposedDestinationIndexPath;
    return [NSIndexPath indexPathForRow:[tableView numberOfRowsInSection:0] - 1 inSection:0];
}

#pragma mark - AwfulForumTreeDataSourceDelegate

- (void)configureCell:(AwfulForumCell *)cell withForum:(AwfulForum *)forum
{
    BOOL hasSubforums = forum.children.count > 0;
    cell.disclosureButton.hidden = !hasSubforums;
    if (hasSubforums) {
        [cell.disclosureButton addTarget:self
                                  action:@selector(toggleExpanded:)
                        forControlEvents:UIControlEventTouchUpInside];
        cell.disclosureButton.selected = [_treeDataSource forumChildrenExpanded:forum];
    }
    cell.textLabel.text = forum.name;
    BOOL isFavorite = [self.favoriteForums containsObject:forum];
    cell.favoriteButton.hidden = isFavorite;
    if (!isFavorite) {
        [cell.favoriteButton addTarget:self
                                action:@selector(toggleFavorite:)
                      forControlEvents:UIControlEventTouchUpInside];
    }
    NSInteger subforumLevel = 0;
    AwfulForum *currentForum = forum.parentForum;
    while (currentForum) {
        subforumLevel++;
        currentForum = currentForum.parentForum;
    }
    cell.subforumLevel = subforumLevel;
    ThemeCell(self.theme, cell);
}

@end
