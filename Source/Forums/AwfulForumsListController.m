//
//  AwfulForumsListController.m
//  Awful
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulForumsListController.h"
#import "AwfulFetchedTableViewControllerSubclass.h"
#import "AwfulAlertView.h"
#import "AwfulAppDelegate.h"
#import "AwfulDataStack.h"
#import "AwfulDisclosureIndicatorView.h"
#import "AwfulForumCell.h"
#import "AwfulHTTPClient.h"
#import "AwfulLepersViewController.h"
#import "AwfulLoginController.h"
#import "AwfulModels.h"
#import "AwfulSettings.h"
#import "AwfulTheme.h"
#import "AwfulThreadListController.h"
#import <Crashlytics/Crashlytics.h>
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
    _favoriteForums = [[self fetchFavoriteForumsWithIDsFromSettings] mutableCopy];
    [self showOrHideEditButton];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(settingsDidChange:)
                                                 name:AwfulSettingsDidChangeNotification
                                               object:nil];
    return self;
}

- (NSArray *)fetchFavoriteForumsWithIDsFromSettings
{
    NSArray *forumIDs = [AwfulSettings settings].favoriteForums;
    if ([forumIDs count] == 0) return @[];
    NSArray *favoriteForums = [AwfulForum fetchAllMatchingPredicate:@"forumID IN %@",
                               [AwfulSettings settings].favoriteForums];
    return [favoriteForums sortedArrayUsingComparator:^NSComparisonResult(AwfulForum *a, AwfulForum *b) {
        return [@([forumIDs indexOfObject:a.forumID]) compare:@([forumIDs indexOfObject:b.forumID])];
    }];
}

- (void)settingsDidChange:(NSNotification *)note
{
    NSArray *changedSettings = note.userInfo[AwfulSettingsDidChangeSettingsKey];
    
    // Refresh the forum list after changing servers.
    if ([changedSettings containsObject:AwfulSettingsKeys.useDevDotForums] ||
        [changedSettings containsObject:AwfulSettingsKeys.customBaseURL]) {
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
    UIBarButtonItem *item = [self.favoriteForums count] > 0 ? self.editButtonItem : nil;
    [self.navigationItem setRightBarButtonItem:item animated:YES];
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
    AwfulForum *forum;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:(id)cell];
    if ([self.favoriteForums count] > 0) {
        indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section - 1];
    }
    if (indexPath.section == -1) {
        forum = self.favoriteForums[indexPath.row];
    } else {
        forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    }
    [self.tableView beginUpdates];
    if (button.selected) {
        CLSLog(@"adding forum %@ to favorites (currently %@)",
               forum.forumID, [self.favoriteForums valueForKey:@"forumID"]);
        [self.favoriteForums addObject:forum];
        if ([self.favoriteForums count] == 1) {
            NSIndexSet *toInsert = [NSIndexSet indexSetWithIndex:0];
            CLSLog(@"inserting sections at %@", toInsert);
            [self.tableView insertSections:toInsert withRowAnimation:UITableViewRowAnimationTop];
            [self showOrHideEditButton];
        } else {
            NSIndexPath *newRow = [NSIndexPath indexPathForRow:[self.favoriteForums count] - 1
                                                     inSection:0];
            CLSLog(@"inserting row at path %@", newRow);
            [self.tableView insertRowsAtIndexPaths:@[ newRow ]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    } else {
        NSInteger row = [self.favoriteForums indexOfObject:forum];
        [self.favoriteForums removeObjectAtIndex:row];
        if ([self.favoriteForums count] == 0) {
            NSIndexSet *toDelete = [NSIndexSet indexSetWithIndex:0];
            CLSLog(@"deleting sections at %@", toDelete);
            [self.tableView deleteSections:toDelete withRowAnimation:UITableViewRowAnimationTop];
            [self showOrHideEditButton];
            self.editing = NO;
        } else {
            NSIndexPath *oldRow = [NSIndexPath indexPathForRow:row inSection:0];
            CLSLog(@"deleting row at path %@", oldRow);
            [self.tableView deleteRowsAtIndexPaths:@[ oldRow ]
                                  withRowAnimation:UITableViewRowAnimationTop];
        }
    }
    if (button.selected) {
        NSIndexPath *nonfavoriteIndexPath = [self.fetchedResultsController indexPathForObject:forum];
        if ([self.favoriteForums count] > 0) {
            nonfavoriteIndexPath = [NSIndexPath indexPathForRow:nonfavoriteIndexPath.row
                                                      inSection:nonfavoriteIndexPath.section + 1];
        }
        CLSLog(@"reloading row at path %@", nonfavoriteIndexPath);
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
    while (cell && ![cell isKindOfClass:[UITableViewCell class]]) cell = cell.superview;
    if (!cell) return;
    AwfulForum *forum;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:(UITableViewCell *)cell];
    if ([self.favoriteForums count] > 0 && indexPath.section == 0) {
        forum = self.favoriteForums[indexPath.row];
    } else {
        if ([self.favoriteForums count] > 0) {
            indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section - 1];
        }
        forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    }
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
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didLogIn:)
                                                 name:AwfulUserDidLogInNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didLogOut:)
                                                 name:AwfulUserDidLogOutNotification object:nil];
}

- (void)didLogIn:(NSNotification *)note
{
    [self.tableView reloadData];
}

- (void)didLogOut:(NSNotification *)note
{
    [self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if ([self.tableView numberOfSections] <= 2) [self.tableView reloadData];
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    if ([self.favoriteForums count] > 0) {
        if (indexPath) {
            indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section + 1];
        }
        if (newIndexPath) {
            newIndexPath = [NSIndexPath indexPathForRow:newIndexPath.row
                                              inSection:newIndexPath.section + 1];
        }
    }
    [super controller:controller
      didChangeObject:anObject
          atIndexPath:indexPath
        forChangeType:type
         newIndexPath:newIndexPath];
}

#pragma mark - UITableViewDataSource and UITableViewDelegate

// Leper's Colony is shown as a pseudo-forum in its own section (the last section).

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    NSInteger extra = 0;
    if ([self shouldShowLepersColony]) extra += 1;
    if ([self.favoriteForums count] > 0) extra += 1;
    return [super numberOfSectionsInTableView:tableView] + extra;
}

- (BOOL)shouldShowLepersColony
{
    return [AwfulHTTPClient client].isLoggedIn;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if ([self shouldShowLepersColony] && section + 1 == [tableView numberOfSections]) {
        return 1;
    } else if ([self.favoriteForums count] > 0 && section == 0) {
        return [self.favoriteForums count];
    } else {
        if ([self.favoriteForums count] > 0) {
            section -= 1;
        }
        return [super tableView:tableView numberOfRowsInSection:section];
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UILabel *header = [AwfulForumHeader new];
    header.frame = (CGRect){ .size = { tableView.bounds.size.width, tableView.rowHeight } };
    header.font = [UIFont boldSystemFontOfSize:15];
    header.textColor = [AwfulTheme currentTheme].forumListHeaderTextColor;
    header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    header.backgroundColor = [AwfulTheme currentTheme].forumListHeaderBackgroundColor;
    if ([self.favoriteForums count] > 0) {
        section -= 1;
    }
    if ([self shouldShowLepersColony] &&
        section == (NSInteger)[self.fetchedResultsController.sections count]) {
        header.text = @"Awful";
    } else if (section == -1) {
        header.text = @"Favorites";
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

- (void)configureCell:(UITableViewCell *)genericCell atIndexPath:(NSIndexPath*)indexPath
{
    AwfulForumCell *cell = (id)genericCell;
    cell.textLabel.textColor = [AwfulTheme currentTheme].forumCellTextColor;
    cell.selectionStyle = [AwfulTheme currentTheme].cellSelectionStyle;
    AwfulDisclosureIndicatorView *disclosure = (AwfulDisclosureIndicatorView *)cell.accessoryView;
    disclosure.color = [AwfulTheme currentTheme].disclosureIndicatorColor;
    disclosure.highlightedColor = [AwfulTheme currentTheme].disclosureIndicatorHighlightedColor;
    if ([self shouldShowLepersColony] &&
        indexPath.section + 1 == [self.tableView numberOfSections]) {
        cell.textLabel.text = @"Leper's Colony";
        cell.showsFavorite = NO;
        cell.showsExpanded = AwfulForumCellShowsExpandedLeavesRoom;
        return;
    }
    AwfulForum *forum;
    BOOL favoritesSection = NO;
    if ([self.favoriteForums count] > 0) {
        indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section - 1];
    }
    if (indexPath.section == -1) {
        forum = self.favoriteForums[indexPath.row];
        favoritesSection = YES;
    } else {
        forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    }
    cell.textLabel.text = forum.name;
    [self setCellImagesForCell:cell];
    cell.showsFavorite = !favoritesSection;
    cell.favorite = [self.favoriteForums containsObject:forum];
    cell.expanded = forum.expandedValue && !favoritesSection;
    if ([forum.children count]) {
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
    if ([self.favoriteForums count] > 0) {
        indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section - 1];
    }
    if (indexPath.section == (NSInteger)[self.fetchedResultsController.sections count]) {
        cell.backgroundColor = [AwfulTheme currentTheme].forumCellBackgroundColor;
    } else if (indexPath.section == -1) {
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
    if ([self.favoriteForums count] > 0) {
        indexPath = [NSIndexPath indexPathForRow:indexPath.row inSection:indexPath.section - 1];
    }
    if (indexPath.section == (NSInteger)[self.fetchedResultsController.sections count]) {
        AwfulLepersViewController *lepersColony = [AwfulLepersViewController new];
        return [self.navigationController pushViewController:lepersColony animated:YES];
    }
    AwfulForum *forum;
    if (indexPath.section == -1) {
        forum = self.favoriteForums[indexPath.row];
    } else {
        forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    }
    AwfulThreadListController *threadList = [AwfulThreadListController new];
    threadList.forum = forum;
    [self.navigationController pushViewController:threadList animated:YES];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self.favoriteForums count] > 0) {
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
    if ([self.favoriteForums count] == 0 || indexPath.section != 0) return;
    AwfulForum *forum = self.favoriteForums[indexPath.row];
    [self.favoriteForums removeObjectAtIndex:indexPath.row];
    if ([self.favoriteForums count] == 0) {
        [tableView deleteSections:[NSIndexSet indexSetWithIndex:0]
                 withRowAnimation:UITableViewRowAnimationTop];
        [self showOrHideEditButton];
        self.editing = NO;
    } else {
        [tableView deleteRowsAtIndexPaths:@[ indexPath ]
                         withRowAnimation:UITableViewRowAnimationAutomatic];
    }
    NSIndexPath *nonfavoriteIndexPath = [self.fetchedResultsController indexPathForObject:forum];
    if ([self.favoriteForums count] > 0) {
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
    return [self.favoriteForums count] > 0 && indexPath.section == 0;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.favoriteForums count] > 0 && indexPath.section == 0;
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

@end
