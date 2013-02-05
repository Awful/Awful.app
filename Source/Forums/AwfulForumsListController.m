//
//  AwfulForumsListController.m
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
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
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self.title = @"Forums";
        self.tabBarItem.image = [UIImage imageNamed:@"list_icon.png"];
    }
    return self;
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
    forum.isFavoriteValue = button.selected;
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:
                                    [AwfulForum entityName]];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"isFavorite == YES"];
    NSError *error;
    if (forum.isFavoriteValue) {
        NSUInteger count = [[AwfulDataStack sharedDataStack].context
                            countForFetchRequest:fetchRequest error:&error];
        if (count == NSNotFound) NSLog(@"Error setting favorite index: %@", error);
        forum.favoriteIndexValue = count;
    } else {
        NSArray *renumber = [[AwfulDataStack sharedDataStack].context
                             executeFetchRequest:fetchRequest error:&error];
        if (!renumber) NSLog(@"Error renumbering favorites: %@", error);
        [renumber enumerateObjectsUsingBlock:^(AwfulForum *favorite, NSUInteger i, BOOL *stop) {
            favorite.favoriteIndexValue = i;
        }];
    }
    [[AwfulDataStack sharedDataStack] save];
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
    id op = [[AwfulHTTPClient client] listForumsAndThen:^(NSError *error, NSArray *forums)
             {
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
    if ([[NSDate date] timeIntervalSinceDate:self.lastRefresh] > 60 * 60 * 20) return YES;
    if ([self.fetchedResultsController.fetchedObjects count] == 0) return YES;
    if ([AwfulForum firstMatchingPredicate:@"index = -1"]) return YES;
    return NO;
}

- (void)retheme
{
    [super retheme];
    self.tableView.separatorColor = [AwfulTheme currentTheme].forumListSeparatorColor;
    self.view.backgroundColor = [AwfulTheme currentTheme].forumListBackgroundColor;
    for (AwfulForumCell *cell in [self.tableView visibleCells]) {
        [self setCellImagesForCell:cell];
        [self tableView:self.tableView
        willDisplayCell:cell
      forRowAtIndexPath:[self.tableView indexPathForCell:cell]];
    }
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
    if ([self.tableView numberOfSections] == 1) [self.tableView reloadData];
}

#pragma mark - UITableViewDataSource

// Leper's Colony is shown as a pseudo-forum in its own section (the last section).

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [super numberOfSectionsInTableView:tableView] + 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section + 1 < [tableView numberOfSections]) {
        return [super tableView:tableView numberOfRowsInSection:section];
    }
    return 1;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    UILabel *header = [AwfulForumHeader new];
    header.frame = (CGRect){ .size = { tableView.bounds.size.width, tableView.rowHeight } };
    header.font = [UIFont boldSystemFontOfSize:15];
    header.textColor = [AwfulTheme currentTheme].forumListHeaderTextColor;
    header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    header.backgroundColor = [AwfulTheme currentTheme].forumListHeaderBackgroundColor;
    if (section + 1 < [tableView numberOfSections]) {
        AwfulForum *anyForum = [[self.fetchedResultsController.sections[section] objects] lastObject];
        header.text = anyForum.category.name;
    } else {
        header.text = @"Awful";
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
        AwfulDisclosureIndicatorView *disclosure = [AwfulDisclosureIndicatorView new];
        disclosure.cell = cell;
        cell.accessoryView = disclosure;
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
    if (indexPath.section + 1 < [self.tableView numberOfSections]) {
        AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
        cell.textLabel.text = forum.name;
        [self setCellImagesForCell:cell];
        cell.showsFavorite = YES;
        cell.favorite = forum.isFavoriteValue;
        cell.expanded = forum.expandedValue;
        if ([forum.children count]) {
            cell.showsExpanded = AwfulForumCellShowsExpandedButton;
        } else {
            cell.showsExpanded = AwfulForumCellShowsExpandedLeavesRoom;
        }
    } else {
        cell.textLabel.text = @"Leper's Colony";
        cell.showsFavorite = NO;
        cell.showsExpanded = AwfulForumCellShowsExpandedLeavesRoom;
    }
}

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section + 1 < [tableView numberOfSections]) {
        AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
        if (forum.parentForum) {
            cell.backgroundColor = [AwfulTheme currentTheme].forumCellSubforumBackgroundColor;
        } else {
            cell.backgroundColor = [AwfulTheme currentTheme].forumCellBackgroundColor;
        }
    } else {
        cell.backgroundColor = [AwfulTheme currentTheme].forumCellBackgroundColor;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section + 1 < [tableView numberOfSections]) {
        AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
        AwfulThreadListController *threadList = [AwfulThreadListController new];
        threadList.forum = forum;
        [self.navigationController pushViewController:threadList animated:YES];
    } else {
        AwfulLepersViewController *lepersColony = [AwfulLepersViewController new];
        [self.navigationController pushViewController:lepersColony animated:YES];
    }
}

@end

