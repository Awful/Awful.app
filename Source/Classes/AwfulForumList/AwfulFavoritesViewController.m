//
//  AwfulFavoritesViewController.m
//  Awful
//
//  Created by Nolan Waite on 12-04-21.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulFavoritesViewController.h"
#import "AwfulForumsListController.h"
#import "AwfulThreadListController.h"
#import "AwfulForumCell.h"

@interface AwfulFavoritesViewController () <NSFetchedResultsControllerDelegate>
@property (readonly, strong, nonatomic) UIBarButtonItem *addButtonItem;
@property (assign, getter = isReordering) BOOL reordering;
@property (assign) BOOL automaticallyAdded;
@property (nonatomic,readwrite,strong) UILabel* noFavorites;
@end

@implementation AwfulFavoritesViewController
@synthesize addButtonItem = _addButtonItem;
@synthesize reordering = _reordering;
@synthesize automaticallyAdded = _automaticallyAdded;
@synthesize noFavorites = _noFavorites;

-(void) awakeFromNib {
    [self setEntityName:@"AwfulForum"
              predicate:@"favorite != nil"
                   sort:@"favorite.displayOrder"
             sectionKey:nil
     ];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.leftBarButtonItem = self.addButtonItem;
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    
    [self setEntityName:@"AwfulForum"
              predicate:@"favorite != nil" 
                   sort:@"favorite.index"
             sectionKey:nil
     ];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:YES];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (!self.automaticallyAdded && self.fetchedResultsController.fetchedObjects.count == 0) {
        //[self addFavorites];
        //self.automaticallyAdded = YES;
    }
    self.tableView.editing = YES;
}


#pragma mark - Awful table view

- (BOOL)canPullToRefresh
{
    return NO;
}

#pragma mark - Table view data source

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    return nil;
}

-(CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * const Identifier = @"AwfulForumCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:Identifier];
    [self configureCell:cell atIndexPath:indexPath];
    cell.showsReorderControl = YES;
    return cell;
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
    forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        AwfulForum *forum = [self.fetchedResultsController objectAtIndexPath:indexPath];
        [ApplicationDelegate.managedObjectContext deleteObject:forum.favorite];
        [ApplicationDelegate saveContext];
    }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

-(BOOL) tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView
    moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath
      toIndexPath:(NSIndexPath *)destinationIndexPath
{
    self.reordering = YES;
    NSMutableArray *reorder = [self.fetchedResultsController.fetchedObjects mutableCopy];
    AwfulForum *move = [reorder objectAtIndex:sourceIndexPath.row];
    [reorder removeObjectAtIndex:sourceIndexPath.row];
    [reorder insertObject:move atIndex:destinationIndexPath.row];
    int i = -100;
    for (AwfulForum* f in reorder) {
        f.favorite.displayOrderValue = i++;
    }
    [ApplicationDelegate saveContext];
    self.reordering = NO;
}

#pragma mark - Table view delegate

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleNone;
}

- (void) tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    for(UIView* view in cell.subviews)
    {
        if([[[view class] description] isEqualToString:@"UITableViewCellReorderControl"])
        {
            //UIView *test = [view copy];
            //test.foX = 0;
            //[cell addSubview:test];
            
        }
    }
}

-(NSString*) tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath {
    return @"Remove";
}

@end
