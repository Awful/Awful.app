//
//  AwfulFetchedTableViewController.m
//  Awful
//
//  Created by me on 5/7/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulFetchedTableViewController.h"
#import "AwfulFetchedTableViewControllerSubclass.h"
#import "AwfulDataStack.h"

@interface AwfulFetchedTableViewController ()

// We had a problem after launching the app where the fetched results controller would load but the
// table view doesn't call its data source. As subsequent changes come in through the FRC, the
// table view gets wise and calls its data source, resulting in invalid numbers of sections or rows.
// With this property we skip change processing while we're off the screen, i.e. the table view
// hasn't fully loaded.
//
// TODO take another look at this and make this property unnecessary.
@property (nonatomic) BOOL hasEverAppeared;

@end


@implementation AwfulFetchedTableViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self getFetchedResultsController:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(getFetchedResultsController:)
                                                 name:AwfulDataStackDidResetNotification
                                               object:[AwfulDataStack sharedDataStack]];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    if (!self.hasEverAppeared) {
        [self.tableView reloadData];
    }
    self.hasEverAppeared = YES;
}

- (void)getFetchedResultsController:(NSNotification *)note
{
    self.fetchedResultsController.delegate = nil;
    self.fetchedResultsController = nil;
    [self.tableView reloadData];
    self.fetchedResultsController = [self createFetchedResultsController];
    self.fetchedResultsController.delegate = self;
    
    NSError *error;
	if (![self.fetchedResultsController performFetch:&error]) {
		// Update to handle the error appropriately.
		NSLog(@"error fetching: %@", error);
	}
}

- (NSFetchedResultsController *)createFetchedResultsController
{
    [NSException raise:NSInternalInconsistencyException
                format:@"Subclasses must implement %@", NSStringFromSelector(_cmd)];
    return nil;
}

- (void)dealloc
{
    self.fetchedResultsController.delegate = nil;
}

#pragma mark - UITableViewDataSource and UITableViewDelegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self.fetchedResultsController.sections count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.fetchedResultsController.sections[section] numberOfObjects];
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    if (self.userDrivenChange || !self.hasEverAppeared) return;
    [self.tableView beginUpdates];
}


- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    if (self.userDrivenChange || !self.hasEverAppeared) return;
    switch (type) {
        case NSFetchedResultsChangeInsert: {
            [self.tableView insertRowsAtIndexPaths:@[newIndexPath]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
        }
        case NSFetchedResultsChangeDelete: {
            [self.tableView deleteRowsAtIndexPaths:@[indexPath]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
        }
        case NSFetchedResultsChangeMove: {
            [self.tableView deleteRowsAtIndexPaths:@[indexPath]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
            [self.tableView insertRowsAtIndexPaths:@[newIndexPath]
                                  withRowAnimation:UITableViewRowAnimationAutomatic];
            break;
        }
        case NSFetchedResultsChangeUpdate: {
            if (self.ignoreUpdates) return;
            [self configureCell:[self.tableView cellForRowAtIndexPath:indexPath]
                    atIndexPath:(newIndexPath ?: indexPath)];
            break;
        }
    }
}

- (void)controller:(NSFetchedResultsController *)controller
  didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex
     forChangeType:(NSFetchedResultsChangeType)type
{
    if (self.userDrivenChange || !self.hasEverAppeared) return;
    switch (type) {
        case NSFetchedResultsChangeInsert: {
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationFade];
            break;
        }
        case NSFetchedResultsChangeDelete: {
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex]
                          withRowAnimation:UITableViewRowAnimationFade];
            break;
        }
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    if (self.userDrivenChange || !self.hasEverAppeared) return;
    [self.tableView endUpdates];
}

@end
