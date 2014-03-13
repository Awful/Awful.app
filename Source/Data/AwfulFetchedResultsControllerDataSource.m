//  AwfulFetchedResultsControllerDataSource.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulFetchedResultsControllerDataSource.h"

@interface AwfulFetchedResultsControllerDataSource () <NSFetchedResultsControllerDelegate>

@end

@implementation AwfulFetchedResultsControllerDataSource
{
    NSMutableIndexSet *_sectionInsertions;
    NSMutableIndexSet *_sectionDeletions;
    BOOL _completedFirstFetch;
}

- (void)dealloc
{
    self.tableView.dataSource = nil;
}

- (id)initWithTableView:(UITableView *)tableView reuseIdentifier:(NSString *)reuseIdentifier
{
    if (!(self = [super init])) return nil;
    _tableView = tableView;
    tableView.dataSource = self;
    _reuseIdentifier = [reuseIdentifier copy];
    _sectionInsertions = [NSMutableIndexSet new];
    _sectionDeletions = [NSMutableIndexSet new];
    return self;
}

- (void)setFetchedResultsController:(NSFetchedResultsController *)fetchedResultsController
{
    _fetchedResultsController.delegate = nil;
    _fetchedResultsController = fetchedResultsController;
    fetchedResultsController.delegate = self;
    _completedFirstFetch = NO;
    [self fetchAndSetDelegateForTableView];
}

- (void)setUpdatesTableView:(BOOL)updatesTableView
{
    if (_updatesTableView == updatesTableView) return;
    _updatesTableView = updatesTableView;
    [self fetchAndSetDelegateForTableView];
}

- (void)fetchAndSetDelegateForTableView
{
    if (self.updatesTableView) {
        if (!_completedFirstFetch) {
            NSError *error;
            BOOL ok = [self.fetchedResultsController performFetch:&error];
            if (!ok) {
                NSLog(@"%s error performing first fetch of fetched results controller: %@", __PRETTY_FUNCTION__, error);
            }
            _completedFirstFetch = ok;
        }
        [self.tableView reloadData];
    }
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

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    if (!self.updatesTableView) return;
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller
  didChangeSection:(id<NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex
     forChangeType:(NSFetchedResultsChangeType)type
{
    if (!self.updatesTableView) return;
    if (type == NSFetchedResultsChangeInsert) {
        [_sectionInsertions addIndex:sectionIndex];
        [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationAutomatic];
    } else if (type == NSFetchedResultsChangeDelete) {
        [_sectionDeletions addIndex:sectionIndex];
        [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)object
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    if (!self.updatesTableView) return;
    if (type == NSFetchedResultsChangeInsert) {
        if (![_sectionInsertions containsIndex:newIndexPath.section]) {
            [self.tableView insertRowsAtIndexPaths:@[ newIndexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    } else if (type == NSFetchedResultsChangeDelete) {
        if (![_sectionDeletions containsIndex:indexPath.section]) {
            [self.tableView deleteRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    } else if (type == NSFetchedResultsChangeUpdate) {
        [self.tableView reloadRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationNone];
    } else if (type == NSFetchedResultsChangeMove) {
        if (![_sectionInsertions containsIndex:newIndexPath.section]) {
            [self.tableView insertRowsAtIndexPaths:@[ newIndexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
        if (![_sectionDeletions containsIndex:indexPath.section]) {
            [self.tableView deleteRowsAtIndexPaths:@[ indexPath ] withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    if (!self.updatesTableView) return;
    [self.tableView endUpdates];
    [_sectionInsertions removeAllIndexes];
    [_sectionDeletions removeAllIndexes];
}

@end
