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

@interface AwfulFavoritesViewController () <NSFetchedResultsControllerDelegate>

@property (strong) NSFetchedResultsController *resultsController;

@property (readonly, strong, nonatomic) UIBarButtonItem *addButtonItem;

@property (assign, getter = isReordering) BOOL reordering;

@property (assign) BOOL automaticallyAdded;

@end

@implementation AwfulFavoritesViewController

- (void)setUpResultsController
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Favorite"];
    NSSortDescriptor *orderDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"displayOrder"
                                                                      ascending:YES];
    NSSortDescriptor *forumDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"forum.index"
                                                                      ascending:YES];
    fetchRequest.sortDescriptors = [NSArray arrayWithObjects:orderDescriptor, forumDescriptor, nil];
    self.resultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest 
                                                                 managedObjectContext:ApplicationDelegate.managedObjectContext
                                                                   sectionNameKeyPath:nil
                                                                            cacheName:nil];
    self.resultsController.delegate = self;
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
    if (!self.automaticallyAdded && self.resultsController.fetchedObjects.count == 0) {
        [self addFavorites];
        self.automaticallyAdded = YES;
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"ThreadList"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        AwfulFavorite *favorite = [self.resultsController objectAtIndexPath:indexPath];
        AwfulThreadListController *list = (AwfulThreadListController *)segue.destinationViewController;
        list.forum = favorite.forum;
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

@synthesize resultsController = _resultsController;

@synthesize addButtonItem = _addButtonItem;

- (UIBarButtonItem *)addButtonItem
{
    if (!_addButtonItem) {
        _addButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd 
                                                                       target:self
                                                                       action:@selector(addFavorites)];
    }
    return _addButtonItem;
}

@synthesize reordering = _reordering;

@synthesize automaticallyAdded = _automaticallyAdded;

- (void)addFavorites
{
    [self performSegueWithIdentifier:@"AddFavorite" sender:self];
}

#pragma mark - Awful table view

- (BOOL)canPullToRefresh
{
    return NO;
}

#pragma mark - Table view data source

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * const Identifier = @"ForumCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:Identifier];
    //[self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(UITableView *)cell atIndexPath:(NSIndexPath *)indexPath
{
    //AwfulFavorite *favorite = [self.resultsController objectAtIndexPath:indexPath];
    //cell.section = [AwfulForumSection sectionWithForum:favorite.forum];
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
    forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        AwfulFavorite *favorite = [self.resultsController objectAtIndexPath:indexPath];
        [ApplicationDelegate.managedObjectContext deleteObject:favorite];
        [ApplicationDelegate saveContext];
    }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (void)tableView:(UITableView *)tableView
    moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath
      toIndexPath:(NSIndexPath *)destinationIndexPath
{
    self.reordering = YES;
    NSMutableArray *reorder = [self.resultsController.fetchedObjects mutableCopy];
    NSManagedObject *whatever = [reorder objectAtIndex:sourceIndexPath.row];
    [reorder removeObjectAtIndex:sourceIndexPath.row];
    [reorder insertObject:whatever atIndex:destinationIndexPath.row];
    for (NSInteger i = 0; i < reorder.count; i += 1) {
        [[reorder objectAtIndex:i] setValue:[NSNumber numberWithInteger:i]
                                     forKey:@"displayOrder"];
    }
    NSError *error;
    BOOL ok = [whatever.managedObjectContext save:&error];
    if(!ok) {
        NSLog(@"error saving favorite order: %@", error);
    }
    self.reordering = NO;
}

#pragma mark - Table view delegate

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
           editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}



@end
