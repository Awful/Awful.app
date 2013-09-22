//  AwfulForumsListController.m
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulForumsListController.h"
#import "AwfulAlertView.h"
#import "AwfulAppDelegate.h"
#import "AwfulFavoriteForumCell.h"
#import "AwfulForumCell.h"
#import "AwfulForumTreeController.h"
#import "AwfulHTTPClient.h"
#import "AwfulModels.h"
#import "AwfulSettings.h"
#import "AwfulThreadListController.h"

@interface AwfulForumsListController () <AwfulForumTreeControllerDelegate>

@property (nonatomic) NSDate *lastRefresh;
@property (nonatomic) NSMutableArray *favoriteForums;
@property (strong, nonatomic) AwfulForumTreeController *treeController;
@property (nonatomic) BOOL userDrivenChange;

@end

@implementation AwfulForumsListController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id)init
{
    if (!(self = [super initWithStyle:UITableViewStylePlain])) return nil;
    self.title = @"Forums";
    self.tabBarItem.image = [UIImage imageNamed:@"list_icon"];
    _favoriteForums = [[self fetchFavoriteForumsWithIDsFromSettings] mutableCopy];
    [self showOrHideEditButton];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsDidChange:)
                                                 name:AwfulSettingsDidChangeNotification
                                               object:nil];
    return self;
}

- (id)initWithStyle:(UITableViewStyle)style
{
    return [self init];
}

- (AwfulForumTreeController *)treeController
{
    if (_treeController) return _treeController;
    _treeController = [AwfulForumTreeController new];
    _treeController.delegate = self;
    return _treeController;
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
    BOOL isFavorite = [self.favoriteForums containsObject:forum];
    [self.tableView beginUpdates];
    BOOL considerFavoritesSectionWhenReloading = YES;
    if (!isFavorite) {
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
    if (!isFavorite) {
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

- (void)refresh
{
    [[AwfulHTTPClient client] listForumsAndThen:^(NSError *error, NSArray *forums) {
        if (!error) {
            self.lastRefresh = [NSDate date];
        }
    }];
}

- (BOOL)refreshOnAppear
{
    if (![AwfulHTTPClient client].loggedIn) return NO;
    if (!self.lastRefresh) return YES;
    if (self.tableView.numberOfSections < 2) return YES;
    if ([[NSDate date] timeIntervalSinceDate:self.lastRefresh] > 60 * 60 * 6) return YES;
    if ([AwfulForum firstMatchingPredicate:@"index = -1"]) return YES;
    return NO;
}

#pragma mark - UIViewController

- (void)loadView
{
    [super loadView];
    [self.tableView registerClass:[UITableViewHeaderFooterView class] forHeaderFooterViewReuseIdentifier:HeaderIdentifier];
    [self.tableView registerClass:[AwfulForumCell class] forCellReuseIdentifier:ForumCellIdentifier];
    [self.tableView registerClass:[AwfulFavoriteForumCell class] forCellReuseIdentifier:FavoriteCellIdentifier];
}

static NSString * const HeaderIdentifier = @"Header";
static NSString * const ForumCellIdentifier = @"Forum";
static NSString * const FavoriteCellIdentifier = @"Favorite";

- (void)themeDidChange
{
    [super themeDidChange];
    [self.tableView reloadData];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.rowHeight = 45;
    self.tableView.backgroundView = nil;
    self.tableView.separatorInset = UIEdgeInsetsMake(0, 37, 0, 0);
    
    // This little ditty stops section headers from sticking. Double the row height to keep section headers out from under a transparent navbar.
    CGRect headerFrame = CGRectMake(0, 0, 0, self.tableView.rowHeight * 2);
    self.tableView.tableHeaderView = [[UIView alloc] initWithFrame:headerFrame];
    UIEdgeInsets contentInset = self.tableView.contentInset;
    contentInset.top -= CGRectGetHeight(headerFrame);
    self.tableView.contentInset = contentInset;
    
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
    [self.favoriteForums removeAllObjects];
    [self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if ([self.tableView numberOfSections] <= 2) [self.tableView reloadData];
    if ([self refreshOnAppear]) {
        [self refresh];
    }
    if (![AwfulHTTPClient client].reachable) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(reachabilityChanged:)
                                                     name:AFNetworkingReachabilityDidChangeNotification
                                                   object:nil];
    }
}

- (void)reachabilityChanged:(NSNotification *)note
{
    if ([self refreshOnAppear]) {
        [self refresh];
    }
}

#pragma mark - UITableViewDataSource and UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSInteger sections = self.treeController.numberOfCategories;
    if (self.favoriteForums.count > 0) {
        sections++;
    }
    return sections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (self.favoriteForums.count > 0 && section == 0) {
        return self.favoriteForums.count;
    }
    if (self.favoriteForums.count > 0) {
        section--;
    }
    return [self.treeController numberOfVisibleForumsInCategoryAtIndex:section];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UITableViewHeaderFooterView *header = [tableView dequeueReusableHeaderFooterViewWithIdentifier:HeaderIdentifier];
    header.contentView.backgroundColor = self.theme[@"forumsListHeaderBackgroundColor"];
    header.textLabel.textColor = self.theme[@"forumsListHeaderTextColor"];
    if (self.favoriteForums.count > 0 && section == 0) {
        header.textLabel.text = @"Favorites";
    } else {
        if (self.favoriteForums.count > 0) {
            section--;
        }
        header.textLabel.text = [self.treeController categoryAtIndex:section].name;
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

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.favoriteForums.count > 0 && indexPath.section == 0) {
        AwfulFavoriteForumCell *cell = [tableView dequeueReusableCellWithIdentifier:FavoriteCellIdentifier
                                                                       forIndexPath:indexPath];
        [self configureFavoriteCell:cell atIndexPath:indexPath];
        return cell;
    } else {
        AwfulForumCell *cell = [tableView dequeueReusableCellWithIdentifier:ForumCellIdentifier
                                                               forIndexPath:indexPath];
        NSIndexPath *adjustedIndexPath = indexPath;
        if (self.favoriteForums.count > 0) {
            adjustedIndexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section - 1];
        }
        [self configureForumCell:cell atAdjustedIndexPath:adjustedIndexPath];
        return cell;
    }
}

- (void)configureFavoriteCell:(AwfulFavoriteForumCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    AwfulForum *forum = self.favoriteForums[indexPath.row];
    cell.textLabel.text = forum.name;
    cell.separatorInset = UIEdgeInsetsZero;
}

- (void)configureForumCell:(AwfulForumCell *)cell atAdjustedIndexPath:(NSIndexPath *)indexPath
{
    AwfulForum *forum = [self.treeController visibleForumAtIndexPath:indexPath];
    BOOL hasSubforums = forum.children.count > 0;
    cell.disclosureButton.hidden = !hasSubforums;
    if (hasSubforums) {
        [cell.disclosureButton addTarget:self
                                  action:@selector(toggleExpanded:)
                        forControlEvents:UIControlEventTouchUpInside];
        cell.disclosureButton.selected = [self.treeController visibleForumExpandedAtIndexPath:indexPath];
    }
    cell.textLabel.text = forum.name;
    BOOL isFavorite = [self.favoriteForums containsObject:forum];
    cell.favoriteButton.hidden = isFavorite;
    if (!isFavorite) {
        [cell.favoriteButton addTarget:self
                                action:@selector(toggleFavorite:)
                      forControlEvents:UIControlEventTouchUpInside];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulForum *forum;
    if (self.favoriteForums.count > 0 && indexPath.section == 0) {
        forum = self.favoriteForums[indexPath.row];
    } else {
        NSIndexPath *adjustedIndexPath = indexPath;
        if (self.favoriteForums.count > 0) {
            adjustedIndexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section - 1];
        }
        forum = [self.treeController visibleForumAtIndexPath:adjustedIndexPath];
    }
    AwfulThreadListController *threadList = [AwfulThreadListController new];
    threadList.forum = forum;
    threadList.restorationClass = [AwfulThreadListController class];
    threadList.restorationIdentifier = @"Thread";
    [self.navigationController pushViewController:threadList animated:YES];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.favoriteForums.count > 0 && indexPath.section == 0) {
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
    [tableView beginUpdates];
    AwfulForum *forum = self.favoriteForums[indexPath.row];
    NSIndexPath *nonfavoriteIndexPath = [self.treeController indexPathForVisibleForum:forum];
    if (self.favoriteForums.count > 0) {
        nonfavoriteIndexPath = [NSIndexPath indexPathForRow:nonfavoriteIndexPath.row
                                                  inSection:nonfavoriteIndexPath.section + 1];
    }
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
    [tableView reloadRowsAtIndexPaths:@[ nonfavoriteIndexPath ] withRowAnimation:UITableViewRowAnimationNone];
    self.userDrivenChange = YES;
    [AwfulSettings settings].favoriteForums = [self.favoriteForums valueForKey:@"forumID"];
    self.userDrivenChange = NO;
    [tableView endUpdates];
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath
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

#pragma mark State preservation and restoration

- (void)encodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super encodeRestorableStateWithCoder:coder];
    [coder encodeObject:self.treeController forKey:TreeControllerKey];
}

- (void)decodeRestorableStateWithCoder:(NSCoder *)coder
{
    [super decodeRestorableStateWithCoder:coder];
    self.treeController = [coder decodeObjectForKey:TreeControllerKey];
    self.treeController.delegate = self;
    [self.tableView reloadData];
}

static NSString * const TreeControllerKey = @"AwfulForumTreeController";

@end
