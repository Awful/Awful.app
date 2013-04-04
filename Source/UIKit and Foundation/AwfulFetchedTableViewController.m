//
//  AwfulFetchedTableViewController.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
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

- (NSFetchedResultsController *)createFetchedResultsController
{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

#pragma mark - UIViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self createFetchedResultsControllerIfNecessary];
    NSNotificationCenter *noteCenter = [NSNotificationCenter defaultCenter];
    [noteCenter addObserver:self selector:@selector(dataStackWillReset:)
                       name:AwfulDataStackWillResetNotification
                     object:[AwfulDataStack sharedDataStack]];
    [noteCenter addObserver:self selector:@selector(dataStackDidReset:)
                       name:AwfulDataStackDidResetNotification
                     object:[AwfulDataStack sharedDataStack]];
}

- (void)createFetchedResultsControllerIfNecessary
{
    if (self.fetchedResultsController) return;
    self.fetchedResultsController = [self createFetchedResultsController];
    self.fetchedResultsController.delegate = self;
    NSError *error;
    if (![self.fetchedResultsController performFetch:&error]) {
        NSLog(@"%@ error fetching: %@", [self class], error);
    }
}

- (void)dataStackWillReset:(NSNotification *)note
{
    self.fetchedResultsController.delegate = nil;
    self.fetchedResultsController = nil;
    [self.tableView reloadData];
}

- (void)dataStackDidReset:(NSNotification *)note
{
    if ([self isViewLoaded]) {
        [self createFetchedResultsControllerIfNecessary];
    }
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

- (void)reachabilityChanged:(NSNotification *)note
{
    if (!self.refreshing && [self refreshOnAppear]) [self refresh];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    self.viewVisible = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AFNetworkingReachabilityDidChangeNotification
                                                  object:nil];
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
                                  withRowAnimation:UITableViewRowAnimationTop];
            break;
        }
        case NSFetchedResultsChangeDelete: {
            [self.tableView deleteRowsAtIndexPaths:@[indexPath]
                                  withRowAnimation:UITableViewRowAnimationTop];
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
            // The NSFetchedResultsControllerDelegate docs get this wrong; sending
            // -configureCell:atIndexPath: now can result in the right cell filled with the wrong
            // object's data if there are inserts or deletes in this table view update block.
            // Reloading the cell fixes this ordering issue.
            // http://oleb.net/blog/2013/02/nsfetchedresultscontroller-documentation-bug/
            [self.tableView reloadRowsAtIndexPaths:@[ indexPath ]
                                  withRowAnimation:UITableViewRowAnimationNone];
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
