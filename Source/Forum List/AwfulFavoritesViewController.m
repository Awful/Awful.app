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
#import "AwfulCustomForums.h"
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
    self.tableView.separatorColor = [UIColor colorWithRed:0.75 green:0.75 blue:0.75 alpha:1.0];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:YES];
    [self.navigationItem.leftBarButtonItem setTintColor:[UIColor colorWithRed:46.0/255
                                                                        green:146.0/255
                                                                         blue:190.0/255
                                                                        alpha:1.0]];
    UIBarMetrics metrics = UIBarMetricsDefault;
    UIImage *background = [[AwfulCSSTemplate defaultTemplate] navigationBarImageForMetrics:metrics];
    [self.navigationController.navigationBar setBackgroundImage:background
                                                  forBarMetrics:metrics];
    BOOL anyFavorites = [self.fetchedResultsController.fetchedObjects count] > 0;
    self.navigationItem.rightBarButtonItem = anyFavorites ? self.editButtonItem : nil;
    if (anyFavorites) {
        [self.coverView removeFromSuperview];
        self.tableView.scrollEnabled = YES;
    } else {
        [self.view insertSubview:self.coverView atIndex:[self.view.subviews count]];
        self.tableView.scrollEnabled = NO;
    }
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
    coverView.backgroundColor = [UIColor whiteColor];
    coverView.opaque = YES;
    UILabel *noFavorites = [UILabel new];
    noFavorites.backgroundColor = [UIColor clearColor];
    noFavorites.text = @"No Favorites";
    noFavorites.font = [UIFont systemFontOfSize:35];
    noFavorites.textColor = [UIColor grayColor];
    [noFavorites sizeToFit];
    noFavorites.center = CGPointMake(coverView.bounds.size.width / 2,
                                     coverView.bounds.size.height / 2);
    [coverView addSubview:noFavorites];
    UILabel *tapAStar = [UILabel new];
    tapAStar.bounds = (CGRect){ .size.width = noFavorites.bounds.size.width };
    tapAStar.backgroundColor = [UIColor clearColor];
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

#pragma mark - Table view data source and delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    return [AwfulForumCell heightForCellWithText:forum.name
                                        fontSize:20
                                   showsFavorite:YES
                                   showsExpanded:NO
                                      tableWidth:tableView.bounds.size.width];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * const Identifier = @"ForumCell";
    AwfulForumCell *cell = [tableView dequeueReusableCellWithIdentifier:Identifier];
    if (!cell) {
        cell = [AwfulForumCell new];
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
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    cell.backgroundColor = [UIColor whiteColor];
    cell.textLabel.textColor = [UIColor blackColor];
}

- (void)forumCellDidToggleFavorite:(AwfulForumCell *)cell
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    forum.isFavoriteValue = cell.favorite;
    [ApplicationDelegate saveContext];
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
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

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
        forum.isFavoriteValue = NO;
        NSArray *reindex = [self.fetchedResultsController fetchedObjects];
        [reindex enumerateObjectsUsingBlock:^(AwfulForum *f, NSUInteger i, BOOL *stop) {
            if (![f isEqual:forum])
                f.favoriteIndexValue = i;
        }];
        [ApplicationDelegate saveContext];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return @"Remove";
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
    AwfulThreadListController *threadList = [AwfulCustomForums threadListControllerForForum:forum];
    threadList.forum = forum;
    [self.navigationController pushViewController:threadList animated:YES];
}

@end
