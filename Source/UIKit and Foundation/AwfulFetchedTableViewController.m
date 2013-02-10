//
//  AwfulFetchedTableViewController.m
//  Awful
//
//  Created by me on 5/7/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulFetchedTableViewController.h"
#import "AwfulFetchedTableViewControllerSubclass.h"
#import "AFNetworking.h"
#import "AwfulDataStack.h"

@interface AwfulFetchedTableViewController ()

// We've had problems updating table views that aren't currently visible.
// Here we avoid updates to specific sections or rows while not visible, then reload the table
// later if we skipped some changes.
@property (getter=isViewVisible, nonatomic) BOOL viewVisible;

@property (nonatomic) BOOL changedWhileNotVisible;

@end


@implementation AwfulFetchedTableViewController
@synthesize fetchedResultsController = _fetchedResultsController;

- (void)reachabilityChanged:(NSNotification *)note
{
    if (!self.refreshing && [self refreshOnAppear]) [self refresh];
}

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
    self.viewVisible = YES;
    if (self.changedWhileNotVisible) {
        [self.tableView reloadData];
    }
    self.changedWhileNotVisible = NO;
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reachabilityChanged:)
                                                 name:AFNetworkingReachabilityDidChangeNotification
                                               object:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    self.viewVisible = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AFNetworkingReachabilityDidChangeNotification
                                                  object:nil];
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
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
    if (self.userDrivenChange) return;
    if (!self.viewVisible) {
        self.changedWhileNotVisible = YES;
        return;
    }
    [self.tableView beginUpdates];
}


- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    if (self.userDrivenChange || !self.viewVisible) return;
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
    if (self.userDrivenChange || !self.viewVisible) return;
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
    if (self.userDrivenChange || !self.viewVisible) return;
    [self.tableView endUpdates];
}

@end
