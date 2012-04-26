//
//  AwfulFavoritesViewController.m
//  Awful
//
//  Created by Nolan Waite on 12-04-21.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulFavoritesViewController.h"
#import "AwfulForumCell.h"
#import "AwfulForumSection.h"
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
    if (!self.resultsController) {
        [self setUpResultsController];
    }
    NSError *error;
    BOOL ok = [self.resultsController performFetch:&error];
    if(!ok) {
        NSLog(@"error fetching favorites: %@", error);
    }
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
    self.navigationItem.rightBarButtonItem = self.addButtonItem;
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
        NSManagedObject *favorite = [self.resultsController objectAtIndexPath:indexPath];
        AwfulForum *forum = [favorite valueForKey:@"forum"];
        AwfulThreadListController *list = (AwfulThreadListController *)segue.destinationViewController;
        list.forum = forum;
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

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.resultsController.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> info = [self.resultsController.sections objectAtIndex:section];
    return [info numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * const Identifier = @"ForumCell";
    AwfulForumCell *cell = (AwfulForumCell *)[tableView dequeueReusableCellWithIdentifier:Identifier];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(AwfulForumCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    NSManagedObject *favorite = [self.resultsController objectAtIndexPath:indexPath];
    cell.section = [AwfulForumSection sectionWithForum:[favorite valueForKey:@"Forum"]];
}

- (void)tableView:(UITableView *)tableView
    commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
    forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObject *favorite = [self.resultsController objectAtIndexPath:indexPath];
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

#pragma mark - Fetched results controller delegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    if (self.reordering) {
        return;
    }
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller
  didChangeSection:(id<NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex
     forChangeType:(NSFetchedResultsChangeType)type
{
    if (type == NSFetchedResultsChangeInsert) {
        [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                      withRowAnimation:UITableViewRowAnimationFade];
    } else if (type == NSFetchedResultsChangeDelete) {
        [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                      withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    if (self.reordering) {
        return;
    }
    if (type == NSFetchedResultsChangeInsert) {
        [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
                              withRowAnimation:UITableViewRowAnimationFade];
    } else if (NSFetchedResultsChangeDelete) {
        [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                              withRowAnimation:UITableViewRowAnimationFade];
    } else if (NSFetchedResultsChangeUpdate) {
        AwfulForumCell *cell = (AwfulForumCell *)[self.tableView cellForRowAtIndexPath:indexPath];
        [self configureCell:cell atIndexPath:indexPath];
    } else if (NSFetchedResultsChangeMove) {
        [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                              withRowAnimation:UITableViewRowAnimationFade];
        [self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:newIndexPath]
                              withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    if (self.reordering) {
        return;
    }
    [self.tableView endUpdates];
}

@end
