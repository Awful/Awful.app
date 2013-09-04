//  AwfulForumsListController.m
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulForumsListController.h"
#import "AwfulAlertView.h"
#import "AwfulAppDelegate.h"
#import "AwfulDisclosureIndicatorView.h"
#import "AwfulForumCell.h"
#import "AwfulForumTreeController.h"
#import "AwfulHTTPClient.h"
#import "AwfulLepersViewController.h"
#import "AwfulModels.h"
#import "AwfulSettings.h"
#import "AwfulTheme.h"
#import "AwfulThreadListController.h"

@interface AwfulForumsListController () <AwfulForumTreeControllerDelegate>

@property (nonatomic) NSDate *lastRefresh;
@property (nonatomic) NSMutableArray *favoriteForums;
@property (nonatomic) AwfulForumTreeController *treeController;
@property (nonatomic) BOOL userDrivenChange;

@end

@interface AwfulForumHeader : UILabel

@end

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
    _favoriteForums = [[self fetchFavoriteForumsWithIDsFromSettings] mutableCopy];
    [self showOrHideEditButton];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsDidChange:)
                                                 name:AwfulSettingsDidChangeNotification
                                               object:nil];
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.treeController = [AwfulForumTreeController new];
    self.treeController.delegate = self;
    return self;
}

- (NSArray *)fetchFavoriteForumsWithIDsFromSettings
{
    NSArray *forumIDs = [AwfulSettings settings].favoriteForums;
    if (forumIDs.count == 0) {
        return @[];
    }
    NSArray *favoriteForums = [AwfulForum fetchAllMatchingPredicate:@"forumID IN %@", forumIDs];
    return [favoriteForums sortedArrayUsingComparator:^(AwfulForum *a, AwfulForum *b) {
        return [@([forumIDs indexOfObject:a.forumID]) compare:@([forumIDs indexOfObject:b.forumID])];
    }];
}

- (void)settingsDidChange:(NSNotification *)note
{
    NSArray *changedSettings = note.userInfo[AwfulSettingsDidChangeSettingsKey];
    
    // Refresh the forum list after changing servers.
    if ([changedSettings containsObject:AwfulSettingsKeys.customBaseURL]) {
        self.lastRefresh = nil;
    }
    
    if (self.userDrivenChange) return;
    
    if ([changedSettings containsObject:AwfulSettingsKeys.favoriteForums]) {
        [self.favoriteForums setArray:[self fetchFavoriteForumsWithIDsFromSettings]];
        [self showOrHideEditButton];
        [self.tableView reloadData];
    }
}

- (void)showOrHideEditButton
{
    UIBarButtonItem *item = self.favoriteForums.count > 0 ? self.editButtonItem : nil;
    [self.navigationItem setRightBarButtonItem:item animated:YES];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
    while (cell && ![cell isKindOfClass:[UITableViewCell class]]) {
        cell = cell.superview;
    }
    if (!cell) return;
    AwfulForum *forum;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:(UITableViewCell *)cell];
    if (self.favoriteForums.count > 0) {
        indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section - 1];
    }
    if (indexPath.section == -1) {
        forum = self.favoriteForums[indexPath.row];
    } else {
        forum = [self.treeController visibleForumAtIndexPath:indexPath];
    }
    [self.tableView beginUpdates];
    BOOL considerFavoritesSectionWhenReloading = YES;
    if (button.selected) {
        [self.favoriteForums addObject:forum];
        if (self.favoriteForums.count == 1) {
            NSIndexSet *toInsert = [NSIndexSet indexSetWithIndex:0];
            [self.tableView insertSections:toInsert withRowAnimation:UITableViewRowAnimationTop];
            considerFavoritesSectionWhenReloading = NO;
            [self showOrHideEditButton];
        } else {
            NSIndexPath *newRow = [NSIndexPath indexPathForRow:self.favoriteForums.count - 1
                                                     inSection:0];
            [self.tableView insertRowsAtIndexPaths:@[ newRow ]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    } else {
        NSInteger row = [self.favoriteForums indexOfObject:forum];
        [self.favoriteForums removeObjectAtIndex:row];
        if (self.favoriteForums.count == 0) {
            NSIndexSet *toDelete = [NSIndexSet indexSetWithIndex:0];
            [self.tableView deleteSections:toDelete withRowAnimation:UITableViewRowAnimationTop];
            [self showOrHideEditButton];
            self.editing = NO;
        } else {
            NSIndexPath *oldRow = [NSIndexPath indexPathForRow:row inSection:0];
            [self.tableView deleteRowsAtIndexPaths:@[ oldRow ]
                                  withRowAnimation:UITableViewRowAnimationTop];
        }
    }
    if (button.selected) {
        NSIndexPath *nonfavoriteIndexPath = [self.treeController indexPathForVisibleForum:forum];
        if (considerFavoritesSectionWhenReloading) {
            nonfavoriteIndexPath = [NSIndexPath indexPathForRow:nonfavoriteIndexPath.row
                                                      inSection:nonfavoriteIndexPath.section + 1];
        }
        [self.tableView reloadRowsAtIndexPaths:@[ nonfavoriteIndexPath ]
                              withRowAnimation:UITableViewRowAnimationNone];
    }
    [self.tableView endUpdates];
    self.userDrivenChange = YES;
    [AwfulSettings settings].favoriteForums = [self.favoriteForums valueForKey:@"forumID"];
    self.userDrivenChange = NO;
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
    if (self.favoriteForums.count > 0) {
        indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section - 1];
    }
    [self.treeController toggleVisibleForumExpandedAtIndexPath:indexPath];
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
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didLogIn:)
                                                 name:AwfulUserDidLogInNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didLogOut:)
                                                 name:AwfulUserDidLogOutNotification object:nil];
}

- (void)didLogIn:(NSNotification *)note
{
    self.treeController = [AwfulForumTreeController new];
    self.treeController.delegate = self;
    [self.tableView reloadData];
}

- (void)didLogOut:(NSNotification *)note
{
    self.treeController = nil;
    [self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if ([self.tableView numberOfSections] <= 2) [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource and UITableViewDelegate

// Leper's Colony is shown as a pseudo-forum in its own section (the last section).

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSInteger sections = self.treeController.numberOfCategories;
    if ([self shouldShowLepersColony]) sections += 1;
    if (self.favoriteForums.count > 0) sections += 1;
    return sections;
}

- (BOOL)shouldShowLepersColony
{
    return [AwfulHTTPClient client].isLoggedIn;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if ([self shouldShowLepersColony] && section + 1 == tableView.numberOfSections) {
        return 1;
    } else if (self.favoriteForums.count > 0 && section == 0) {
        return self.favoriteForums.count;
    } else {
        if (self.favoriteForums.count > 0) {
            section -= 1;
        }
        return [self.treeController numberOfVisibleForumsInCategoryAtIndex:section];
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UILabel *header = [AwfulForumHeader new];
    header.font = [UIFont boldSystemFontOfSize:15];
    header.textColor = [AwfulTheme currentTheme].forumListHeaderTextColor;
    header.backgroundColor = [AwfulTheme currentTheme].forumListHeaderBackgroundColor;
    if (self.favoriteForums.count > 0) {
        section -= 1;
    }
    if ([self shouldShowLepersColony] &&
        section == (NSInteger)self.treeController.numberOfCategories) {
        header.text = @"Awful";
    } else if (section == -1) {
        header.text = @"Favorites";
    } else {
        header.text = [self.treeController categoryAtIndex:section].name;
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

- (void)configureCell:(UITableViewCell *)genericCell atIndexPath:(NSIndexPath*)indexPath
{
    AwfulForumCell *cell = (id)genericCell;
    cell.textLabel.textColor = [AwfulTheme currentTheme].forumCellTextColor;
    cell.selectionStyle = [AwfulTheme currentTheme].cellSelectionStyle;
    AwfulDisclosureIndicatorView *disclosure = (AwfulDisclosureIndicatorView *)cell.accessoryView;
    disclosure.color = [AwfulTheme currentTheme].disclosureIndicatorColor;
    disclosure.highlightedColor = [AwfulTheme currentTheme].disclosureIndicatorHighlightedColor;
    if ([self shouldShowLepersColony] && indexPath.section + 1 == self.tableView.numberOfSections) {
        cell.textLabel.text = @"Leper's Colony";
        cell.showsFavorite = NO;
        cell.showsExpanded = AwfulForumCellShowsExpandedLeavesRoom;
        return;
    }
    AwfulForum *forum;
    BOOL favoritesSection = NO;
    if (self.favoriteForums.count > 0) {
        if (indexPath.section == 0) {
            forum = self.favoriteForums[indexPath.row];
            favoritesSection = YES;
        } else {
            indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section - 1];
        }
    }
    if (!forum) {
        forum = [self.treeController visibleForumAtIndexPath:indexPath];
    }
    cell.textLabel.text = forum.name;
    [self setCellImagesForCell:cell];
    cell.showsFavorite = !favoritesSection;
    cell.favorite = [self.favoriteForums containsObject:forum];
    cell.expanded = !favoritesSection && [self.treeController visibleForumExpandedAtIndexPath:indexPath];
    if (forum.children.count) {
        if (favoritesSection) {
            cell.showsExpanded = AwfulForumCellShowsExpandedLeavesRoom;
        } else {
            cell.showsExpanded = AwfulForumCellShowsExpandedButton;
        }
    } else {
        cell.showsExpanded = AwfulForumCellShowsExpandedLeavesRoom;
    }
    cell.editingAccessoryView = favoritesSection ? nil : cell.accessoryView;
}

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.favoriteForums.count > 0) {
        indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section - 1];
    }
    if (indexPath.section == (NSInteger)self.treeController.numberOfCategories) {
        cell.backgroundColor = [AwfulTheme currentTheme].forumCellBackgroundColor;
    } else if (indexPath.section == -1) {
        cell.backgroundColor = [AwfulTheme currentTheme].forumCellBackgroundColor;
    } else {
        AwfulForum *forum = [self.treeController visibleForumAtIndexPath:indexPath];
        if (forum.parentForum) {
            cell.backgroundColor = [AwfulTheme currentTheme].forumCellSubforumBackgroundColor;
        } else {
            cell.backgroundColor = [AwfulTheme currentTheme].forumCellBackgroundColor;
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.favoriteForums.count > 0) {
        indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section - 1];
    }
    if (indexPath.section == (NSInteger)self.treeController.numberOfCategories) {
        AwfulLepersViewController *lepersColony = [AwfulLepersViewController new];
        return [self.navigationController pushViewController:lepersColony animated:YES];
    }
    AwfulForum *forum;
    if (indexPath.section == -1) {
        forum = self.favoriteForums[indexPath.row];
    } else {
        forum = [self.treeController visibleForumAtIndexPath:indexPath];
    }
    AwfulThreadListController *threadList = [AwfulThreadListController new];
    threadList.forum = forum;
    [self.navigationController pushViewController:threadList animated:YES];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.favoriteForums.count > 0) {
        indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section - 1];
    }
    if (indexPath.section == -1) {
        return UITableViewCellEditingStyleDelete;
    } else {
        return UITableViewCellEditingStyleNone;
    }
}

- (NSString *)tableView:(UITableView *)tableView
    titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return @"Remove";
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle != UITableViewCellEditingStyleDelete) return;
    if (self.favoriteForums.count == 0 || indexPath.section != 0) return;
    AwfulForum *forum = self.favoriteForums[indexPath.row];
    [self.favoriteForums removeObjectAtIndex:indexPath.row];
    if (self.favoriteForums.count == 0) {
        [tableView deleteSections:[NSIndexSet indexSetWithIndex:0]
                 withRowAnimation:UITableViewRowAnimationTop];
        [self showOrHideEditButton];
        self.editing = NO;
    } else {
        [tableView deleteRowsAtIndexPaths:@[ indexPath ]
                         withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    NSIndexPath *nonfavoriteIndexPath = [self.treeController indexPathForVisibleForum:forum];
    if (self.favoriteForums.count > 0) {
        nonfavoriteIndexPath = [NSIndexPath indexPathForRow:nonfavoriteIndexPath.row
                                                  inSection:nonfavoriteIndexPath.section + 1];
    }
    AwfulForumCell *nonfavoriteCell = (id)[tableView cellForRowAtIndexPath:nonfavoriteIndexPath];
    nonfavoriteCell.favoriteButton.selected = NO;
    self.userDrivenChange = YES;
    [AwfulSettings settings].favoriteForums = [self.favoriteForums valueForKey:@"forumID"];
    self.userDrivenChange = NO;
}

- (BOOL)tableView:(UITableView *)tableView
shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    return self.favoriteForums.count > 0 && indexPath.section == 0;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return self.favoriteForums.count > 0 && indexPath.section == 0;
}

- (NSIndexPath *)tableView:(UITableView *)tableView
targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath
       toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath
{
    if (proposedDestinationIndexPath.section == 0) return proposedDestinationIndexPath;
    return [NSIndexPath indexPathForRow:[tableView numberOfRowsInSection:0] - 1
                              inSection:0];
}

- (void)tableView:(UITableView *)tableView
moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath
      toIndexPath:(NSIndexPath *)destinationIndexPath
{
    id forum = self.favoriteForums[sourceIndexPath.row];
    [self.favoriteForums removeObjectAtIndex:sourceIndexPath.row];
    [self.favoriteForums insertObject:forum atIndex:destinationIndexPath.row];
    self.userDrivenChange = YES;
    [AwfulSettings settings].favoriteForums = [self.favoriteForums valueForKey:@"forumID"];
    self.userDrivenChange = NO;
}

#pragma mark AwfulForumTreeControllerDelegate

- (void)forumTreeControllerWillUpdate:(AwfulForumTreeController *)treeController
{
    [self.tableView beginUpdates];
}

- (void)forumTreeController:(AwfulForumTreeController *)treeController
            categoryAtIndex:(NSInteger)index
                  didChange:(AwfulForumTreeControllerChangeType)changeType
{
    if (self.favoriteForums.count > 0) {
        index++;
    }
    NSIndexSet *sections = [NSIndexSet indexSetWithIndex:index];
    if (changeType == AwfulForumTreeControllerChangeTypeDelete) {
        [self.tableView deleteSections:sections withRowAnimation:UITableViewRowAnimationAutomatic];
    } else if (changeType == AwfulForumTreeControllerChangeTypeInsert) {
        [self.tableView insertSections:sections withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (void)forumTreeController:(AwfulForumTreeController *)treeController
    visibleForumAtIndexPath:(NSIndexPath *)indexPath
                  didChange:(AwfulForumTreeControllerChangeType)changeType
{
    if (self.favoriteForums.count > 0) {
        indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section + 1];
    }
    switch (changeType) {
        case AwfulForumTreeControllerChangeTypeDelete:
            [self.tableView deleteRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
            
        case AwfulForumTreeControllerChangeTypeInsert:
            [self.tableView insertRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
            
        case AwfulForumTreeControllerChangeTypeUpdate:
            [self.tableView reloadRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
    }
}

- (void)forumTreeControllerDidUpdate:(AwfulForumTreeController *)treeController
{
    [self.tableView endUpdates];
}

@end
