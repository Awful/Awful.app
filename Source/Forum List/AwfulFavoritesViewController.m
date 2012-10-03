//
//  AwfulFavoritesViewController.m
//  Awful
//
//  Created by Nolan Waite on 12-04-21.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulFavoritesViewController.h"
#import "AwfulFetchedTableViewControllerSubclass.h"
#import "AwfulForumsListController.h"
#import "AwfulThreadListController.h"
#import "AwfulForumCell.h"
#import "AwfulSettings.h"
#import "AwfulCSSTemplate.h"

@interface AwfulFavoritesViewController () <AwfulForumCellDelegate>

@property (readonly, strong, nonatomic) UIBarButtonItem *addButtonItem;
@property (assign, nonatomic) BOOL automaticallyAdded;
@property (weak, nonatomic) UIView *coverView;

@end

@implementation AwfulFavoritesViewController

- (NSFetchedResultsController *)createFetchedResultsController
{
    NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:[AwfulForum entityName]];
    request.predicate = [NSPredicate predicateWithFormat:@"isFavorite = YES"];
    request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"favoriteIndex"
                                                              ascending:YES]];
    return [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                               managedObjectContext:ApplicationDelegate.managedObjectContext
                                                 sectionNameKeyPath:nil
                                                          cacheName:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if ([self.fetchedResultsController.fetchedObjects count] > 0) {
        self.navigationItem.rightBarButtonItem = self.editButtonItem;
        [self hideNoFavoritesCover];
    } else {
        self.navigationItem.rightBarButtonItem = nil;
        [self showNoFavoritesCoverAnimated:NO];
    }
}

- (void)showNoFavoritesCoverAnimated:(BOOL)animated
{
    self.tableView.scrollEnabled = NO;
    UIView *cover = self.coverView;
    [UIView transitionWithView:self.view
                      duration:animated ? 0.6 : 0
                       options:UIViewAnimationOptionTransitionCurlDown
                    animations:^{ [self.view addSubview:cover]; }
                    completion:nil];
}

- (void)hideNoFavoritesCover
{
    [self.coverView removeFromSuperview];
    self.tableView.scrollEnabled = YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    UITableViewCell* cell = (UITableViewCell*)sender;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    
    AwfulThreadListController *list = (AwfulThreadListController *)segue.destinationViewController;
    list.forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
}

- (UIView *)coverView
{
    if (_coverView) {
        return _coverView;
    }
    UIView *coverView = [[UIView alloc] initWithFrame:(CGRect){ .size = self.view.bounds.size }];
    coverView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    coverView.backgroundColor = self.tableView.backgroundColor;
    coverView.opaque = YES;
    UILabel *noFavorites = [UILabel new];
    noFavorites.backgroundColor = self.tableView.backgroundColor;
    noFavorites.text = @"No Favorites";
    noFavorites.font = [UIFont systemFontOfSize:35];
    noFavorites.textColor = [UIColor grayColor];
    [noFavorites sizeToFit];
    noFavorites.center = CGPointMake(coverView.bounds.size.width / 2,
                                     coverView.bounds.size.height / 2);
    [coverView addSubview:noFavorites];
    UILabel *tapAStar = [UILabel new];
    tapAStar.bounds = (CGRect){ .size.width = noFavorites.bounds.size.width };
    tapAStar.backgroundColor = self.tableView.backgroundColor;
    tapAStar.text = @"Tap a star in the forums list to add one.";
    tapAStar.font = [UIFont systemFontOfSize:16];
    tapAStar.textColor = [UIColor grayColor];
    [tapAStar sizeToFit];
    tapAStar.center = CGPointMake(noFavorites.center.x,
                                  noFavorites.center.y + noFavorites.bounds.size.height / 1.5);
    [coverView addSubview:tapAStar];
    _coverView = coverView;
    return coverView;
}

#pragma mark - Awful table view

- (BOOL)canPullToRefresh
{
    return NO;
}

#pragma mark - Fetched results controller delegate

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)object
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    [super controller:controller
      didChangeObject:object
          atIndexPath:indexPath
        forChangeType:type
         newIndexPath:newIndexPath];
    if ([controller.fetchedObjects count] == 0) {
        [self showNoFavoritesCoverAnimated:YES];
    }
}

#pragma mark - Table view data source and delegate

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

- (void)configureCell:(UITableViewCell *)genericCell atIndexPath:(NSIndexPath *)indexPath
{
    AwfulForumCell *cell = (AwfulForumCell *)genericCell;
    cell.delegate = self;
    AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text = forum.name;
    cell.showsExpanded = NO;
    cell.showsFavorite = NO;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
}

- (void)tableView:(UITableView *)tableView
  willDisplayCell:(UITableViewCell *)cell
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.backgroundColor = [UIColor whiteColor];
}

- (void)forumCellDidToggleFavorite:(AwfulForumCell *)cell
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    forum.isFavoriteValue = cell.favorite;
    [ApplicationDelegate saveContext];
}

- (void)tableView:(UITableView *)tableView
    moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath
    toIndexPath:(NSIndexPath *)destinationIndexPath
{
    self.userDrivenChange = YES;
    NSMutableArray *reorder = [self.fetchedResultsController.fetchedObjects mutableCopy];
    AwfulForum *move = [reorder objectAtIndex:sourceIndexPath.row];
    [reorder removeObjectAtIndex:sourceIndexPath.row];
    [reorder insertObject:move atIndex:destinationIndexPath.row];
    [reorder enumerateObjectsUsingBlock:^(AwfulForum *forum, NSUInteger i, BOOL *stop) {
        forum.favoriteIndexValue = i;
    }];
    [ApplicationDelegate saveContext];
    self.userDrivenChange = NO;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
    forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
        forum.isFavoriteValue = NO;
        NSArray *reindex = [self.fetchedResultsController fetchedObjects];
        [reindex enumerateObjectsUsingBlock:^(AwfulForum *f, NSUInteger i, BOOL *stop) {
            if (f.isFavoriteValue)
                f.favoriteIndexValue = i;
        }];
        [ApplicationDelegate saveContext];
    }
}

- (NSString *)tableView:(UITableView *)tableView
    titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return @"Remove";
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    AwfulThreadListController *threadList = [AwfulThreadListController new];
    threadList.forum = forum;
    [self.navigationController pushViewController:threadList animated:YES];
}

@end
