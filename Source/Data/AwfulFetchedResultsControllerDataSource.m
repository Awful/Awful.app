//  AwfulFetchedResultsControllerDataSource.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulFetchedResultsControllerDataSource.h"

@interface AwfulFetchedResultsControllerDataSource () <NSFetchedResultsControllerDelegate>

@end

@implementation AwfulFetchedResultsControllerDataSource
{
    NSMutableIndexSet *_pendingSectionInsertions;
    NSMutableIndexSet *_pendingSectionDeletions;
    NSMutableOrderedSet *_pendingRowInsertions;
    NSMutableOrderedSet *_pendingRowDeletions;
    NSMutableOrderedSet *_pendingRowUpdates;
    BOOL _didFirstReload;
}

- (id)initWithTableView:(UITableView *)tableView reuseIdentifier:(NSString *)reuseIdentifier
{
    if (!(self = [super init])) return nil;
    _tableView = tableView;
    tableView.dataSource = self;
    _reuseIdentifier = [reuseIdentifier copy];
    _pendingSectionInsertions = [NSMutableIndexSet new];
    _pendingSectionDeletions = [NSMutableIndexSet new];
    _pendingRowInsertions = [NSMutableOrderedSet new];
    _pendingRowDeletions = [NSMutableOrderedSet new];
    _pendingRowUpdates = [NSMutableOrderedSet new];
    return self;
}

- (void)setFetchedResultsController:(NSFetchedResultsController *)fetchedResultsController
{
    _fetchedResultsController.delegate = nil;
    _fetchedResultsController = fetchedResultsController;
    _fetchedResultsController.delegate = self;
    self.paused = YES;
    _didFirstReload = NO;
}

- (void)setPaused:(BOOL)paused
{
    _paused = paused;
    if (!paused) {
        if (_didFirstReload) {
            [self replayPendingChanges];
        } else {
            NSError *error;
            BOOL ok = [self.fetchedResultsController performFetch:&error];
            if (!ok) {
                NSLog(@"%s error performing first fetch of fetched results controller: %@", __PRETTY_FUNCTION__, error);
            }
            [self.tableView reloadData];
            _didFirstReload = YES;
        }
    }
}

- (NSUInteger)numberOfPendingChanges
{
    return (_pendingSectionInsertions.count +
            _pendingSectionDeletions.count +
            _pendingRowInsertions.count +
            _pendingRowDeletions.count +
            _pendingRowUpdates.count);
}

- (void)replayPendingChanges
{
    if (self.numberOfPendingChanges > 50) {
        [self.tableView reloadData];
    } else {
        [self.tableView beginUpdates];
        [self.tableView insertSections:_pendingSectionInsertions withRowAnimation:UITableViewRowAnimationAutomatic];
        [self.tableView deleteSections:_pendingSectionDeletions withRowAnimation:UITableViewRowAnimationAutomatic];
        [self.tableView insertRowsAtIndexPaths:_pendingRowInsertions.array withRowAnimation:UITableViewRowAnimationAutomatic];
        [self.tableView deleteRowsAtIndexPaths:_pendingRowDeletions.array withRowAnimation:UITableViewRowAnimationAutomatic];
        [self.tableView reloadRowsAtIndexPaths:_pendingRowUpdates.array withRowAnimation:UITableViewRowAnimationAutomatic];
        [self.tableView endUpdates];
    }
    [_pendingSectionInsertions removeAllIndexes];
    [_pendingSectionDeletions removeAllIndexes];
    [_pendingRowInsertions removeAllObjects];
    [_pendingRowDeletions removeAllObjects];
    [_pendingRowUpdates removeAllObjects];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.fetchedResultsController.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = self.fetchedResultsController.sections[section];
    return sectionInfo.numberOfObjects;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:self.reuseIdentifier forIndexPath:indexPath];
    [self.delegate configureCell:cell withObject:[self.fetchedResultsController objectAtIndexPath:indexPath]];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (![self.delegate respondsToSelector:@selector(canDeleteObject:atIndexPath:)]) return NO;
    id object = [self.fetchedResultsController objectAtIndexPath:indexPath];
    return [self.delegate canDeleteObject:object atIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView
commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle != UITableViewCellEditingStyleDelete) return;
    [self.delegate deleteObject:[self.fetchedResultsController objectAtIndexPath:indexPath]];
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controller:(NSFetchedResultsController *)controller
  didChangeSection:(id<NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex
     forChangeType:(NSFetchedResultsChangeType)type
{
    if (type == NSFetchedResultsChangeInsert) {
        [_pendingSectionInsertions addIndex:sectionIndex];
    } else if (type == NSFetchedResultsChangeDelete) {
        [_pendingSectionDeletions addIndex:sectionIndex];
    }
}

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)object
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    if (type == NSFetchedResultsChangeInsert) {
        if (![_pendingSectionInsertions containsIndex:newIndexPath.section]) {
            [_pendingRowInsertions addObject:newIndexPath];
        }
    } else if (type == NSFetchedResultsChangeDelete) {
        if (![_pendingSectionDeletions containsIndex:indexPath.section]) {
            [_pendingRowDeletions addObject:indexPath];
        }
    } else if (type == NSFetchedResultsChangeUpdate) {
        [_pendingRowUpdates addObject:indexPath];
    } else if (type == NSFetchedResultsChangeMove) {
        if (![_pendingSectionInsertions containsIndex:newIndexPath.section]) {
            [_pendingRowInsertions addObject:newIndexPath];
        }
        if (![_pendingSectionDeletions containsIndex:indexPath.section]) {
            [_pendingRowDeletions addObject:indexPath];
        }
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    if (!self.paused) {
        [self replayPendingChanges];
    }
}

@end
