//
//  AwfulForumsListController.m
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulForumsListController.h"
#import "AwfulFetchedTableViewControllerSubclass.h"
#import "AwfulAppDelegate.h"
#import "AwfulDataStack.h"
#import "AwfulForumCell.h"
#import "AwfulForumHeader.h"
#import "AwfulHTTPClient.h"
#import "AwfulModels.h"
#import "AwfulLoginController.h"
#import "AwfulSettings.h"
#import "AwfulThreadListController.h"

@interface AwfulForumsListController () <AwfulForumCellDelegate>

@property (nonatomic) NSDate *lastRefresh;

@end


@implementation AwfulForumsListController

- (id)init
{
    self = [super initWithStyle:UITableViewStyleGrouped];
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

- (void)showForum:(AwfulForum *)forum
{
    AwfulThreadListController *threadList = [AwfulThreadListController new];
    threadList.forum = forum;
    [self.navigationController pushViewController:threadList animated:YES];
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

#pragma mark - AwfulTableViewController

- (void)refresh
{
    [super refresh];
    [self.networkOperation cancel];
    id op = [[AwfulHTTPClient client] listForumsAndThen:^(NSError *error, NSArray *forums)
             {
                 if (error) {
                     [[AwfulAppDelegate instance] requestFailed:error];
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
    if (!IsLoggedIn()) return NO;
    if (!self.lastRefresh) return YES;
    return [[NSDate date] timeIntervalSinceDate:self.lastRefresh] > 60 * 60 * 20;
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.separatorColor = [UIColor colorWithWhite:0.94 alpha:1];
    self.tableView.rowHeight = 50;
    self.view.backgroundColor = [UIColor colorWithWhite:0.333 alpha:1];
    self.tableView.backgroundView = nil;
    
    // Bump table view contents down so the first section header is nicely spaced from the top.
    self.tableView.contentInset = UIEdgeInsetsMake(10, 0, 0, 0);
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if (IsLoggedIn() && [self.fetchedResultsController.sections count] == 0) {
       [self refresh];
    }
}

#pragma mark - Table view data source

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    AwfulForumHeader *header = [AwfulForumHeader new];
    header.backgroundColor = tableView.backgroundColor;
    AwfulForum *anyForum = [[self.fetchedResultsController.sections[section] objects] lastObject];
    header.textLabel.text = anyForum.category.name;
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return [AwfulForumHeader height];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * const Identifier = @"ForumCell";
    AwfulForumCell *cell = [tableView dequeueReusableCellWithIdentifier:Identifier];
    if (!cell) {
        cell = [[AwfulForumCell alloc] initWithReuseIdentifier:Identifier];
    }
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(UITableViewCell *)plainCell atIndexPath:(NSIndexPath*)indexPath
{
    AwfulForumCell *cell = (AwfulForumCell *)plainCell;
    AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.delegate = self;
    cell.textLabel.text = forum.name;
    cell.favorite = forum.isFavoriteValue;
    cell.showsFavorite = YES;
    cell.expanded = forum.expandedValue;
    if ([forum.children count]) {
        cell.showsExpanded = AwfulForumCellShowsExpandedButton;
    } else {
        cell.showsExpanded = AwfulForumCellShowsExpandedLeavesRoom;
    }
}

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    if (forum.parentForum) {
        cell.backgroundColor = [UIColor colorWithRed:0.922 green:0.922 blue:0.925 alpha:1];
    } else {
        cell.backgroundColor = [UIColor whiteColor];
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    [self showForum:forum];
}

#pragma mark - Parent forum cell delegate

- (void)forumCellDidToggleFavorite:(AwfulForumCell *)cell
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    forum.isFavoriteValue = cell.favorite;
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[AwfulForum entityName]];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"isFavorite == YES"];
    NSError *error;
    if (cell.favorite) {
        NSUInteger count = [[AwfulDataStack sharedDataStack].context countForFetchRequest:fetchRequest
                                                                                    error:&error];
        if (count == NSNotFound) {
            NSLog(@"Error setting favorite index: %@", error);
        }
        forum.favoriteIndexValue = count;
    } else {
        NSArray *renumber = [[AwfulDataStack sharedDataStack].context executeFetchRequest:fetchRequest
                                                                                    error:&error];
        if (!renumber) {
            NSLog(@"Error renumbering favorites: %@", error);
        }
        [renumber enumerateObjectsUsingBlock:^(AwfulForum *favorite, NSUInteger i, BOOL *stop) {
            favorite.favoriteIndexValue = i;
        }];
    }
    [[AwfulDataStack sharedDataStack] save];
}

- (void)forumCellDidToggleExpanded:(AwfulForumCell *)cell
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    if (cell.expanded) {
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

@end

