//  AwfulForumTreeController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulForumTreeController.h"
#import "AwfulDataStack.h"

@interface AwfulForumTreeController () <NSFetchedResultsControllerDelegate>

@end

@implementation AwfulForumTreeController
{
    NSFetchedResultsController *_frc;
    NSMutableArray *_hiddenForumsInCategory;
    NSMutableIndexSet *_newlyInsertedSections;
}

- (id)init
{
    if (!(self = [super init])) return nil;
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[AwfulForum entityName]];
    fetchRequest.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"category.index" ascending:YES],
                                      [NSSortDescriptor sortDescriptorWithKey:@"index" ascending:YES] ];
    _frc = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                               managedObjectContext:[AwfulDataStack sharedDataStack].context
                                                 sectionNameKeyPath:@"category.index"
                                                          cacheName:nil];
    _frc.delegate = self;
    _hiddenForumsInCategory = [NSMutableArray new];
    
    NSError *error;
    BOOL ok = [_frc performFetch:&error];
    if (!ok) {
        NSLog(@"error during initial fetch in forum tree controller: %@", error);
        return nil;
    }
    for (id <NSFetchedResultsSectionInfo> section in _frc.sections) {
        [_hiddenForumsInCategory addObject:[self initialHiddenForumsWithSection:section]];
    }
    return self;
}

- (NSMutableIndexSet *)initialHiddenForumsWithSection:(id <NSFetchedResultsSectionInfo>)section
{
    NSMutableIndexSet *hiddenForums = [NSMutableIndexSet new];
    [section.objects enumerateObjectsUsingBlock:^(AwfulForum *forum, NSUInteger i, BOOL *stop) {
        if (forum.parentForum) {
            [hiddenForums addIndex:i];
        }
    }];
    return hiddenForums;
}

- (NSInteger)numberOfCategories
{
    return _frc.sections.count;
}

- (AwfulCategory *)categoryAtIndex:(NSInteger)index
{
    id <NSFetchedResultsSectionInfo> section = _frc.sections[index];
    AwfulForum *forum = section.objects[0];
    return forum.category;
}

- (NSInteger)numberOfVisibleForumsInCategoryAtIndex:(NSInteger)index
{
    id <NSFetchedResultsSectionInfo> section = _frc.sections[index];
    NSIndexSet *hiddenForums = _hiddenForumsInCategory[index];
    return section.numberOfObjects - hiddenForums.count;
}

- (AwfulForum *)visibleForumAtIndexPath:(NSIndexPath *)visibleIndexPath
{
    NSIndexPath *indexPath = [self realIndexPathForVisibleIndexPath:visibleIndexPath];
    return [_frc objectAtIndexPath:indexPath];
}

- (NSIndexPath *)indexPathForVisibleForum:(AwfulForum *)visibleForum
{
    NSIndexPath *realIndexPath = [_frc indexPathForObject:visibleForum];
    NSIndexSet *hiddenForums = _hiddenForumsInCategory[realIndexPath.section];
    if ([hiddenForums containsIndex:realIndexPath.row]) {
        return nil;
    } else {
        NSRange range = NSMakeRange(0, realIndexPath.row);
        NSInteger visibleIndex = realIndexPath.row - [hiddenForums countOfIndexesInRange:range];
        return [NSIndexPath indexPathForRow:visibleIndex inSection:realIndexPath.section];
    }
}

- (NSIndexPath *)realIndexPathForVisibleIndexPath:(NSIndexPath *)visibleIndexPath
{
    NSIndexSet *hiddenForums = _hiddenForumsInCategory[visibleIndexPath.section];
    __block NSInteger realIndex = visibleIndexPath.row;
    [hiddenForums enumerateRangesUsingBlock:^(NSRange range, BOOL *stop) {
        if ((NSInteger)range.location <= realIndex) {
            realIndex += range.length;
        } else {
            *stop = YES;
        }
    }];
    return [NSIndexPath indexPathForRow:realIndex inSection:visibleIndexPath.section];
}

- (BOOL)visibleForumExpandedAtIndexPath:(NSIndexPath *)indexPath
{
    NSIndexPath *realIndexPath = [self realIndexPathForVisibleIndexPath:indexPath];
    NSIndexSet *hiddenForums = _hiddenForumsInCategory[indexPath.section];
    return [hiddenForums containsIndex:realIndexPath.row];
}

- (void)toggleVisibleForumExpandedAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulForum *forum = [self visibleForumAtIndexPath:indexPath];
    if (forum.children.count == 0) {
        return;
    }
    NSIndexPath *realIndexPath = [_frc indexPathForObject:forum];
    NSMutableIndexSet *hiddenForums = _hiddenForumsInCategory[indexPath.section];
    [self.delegate forumTreeControllerWillUpdate:self];
    if ([hiddenForums containsIndex:realIndexPath.row + 1]) {
        // Expand (show all children of) this forum.
        [forum.children enumerateObjectsUsingBlock:^(AwfulForum *subforum, NSUInteger i, BOOL *stop) {
            [hiddenForums removeIndex:[_frc indexPathForObject:subforum].row];
            NSIndexPath *insertIndexPath = [NSIndexPath indexPathForRow:indexPath.row + i + 1
                                                              inSection:indexPath.section];
            [self.delegate forumTreeController:self
                       visibleForumAtIndexPath:insertIndexPath
                                     didChange:AwfulForumTreeControllerChangeTypeInsert];
        }];
    } else {
        // Collapse (hide all ancestors of) this forum.
        AwfulForum *lastAncestor = forum;
        while (lastAncestor.children.count > 0) {
            lastAncestor = lastAncestor.children.lastObject;
        }
        NSIndexPath *lastRealIndexPath = [_frc indexPathForObject:lastAncestor];
        NSRange range = NSMakeRange(realIndexPath.row + 1, lastRealIndexPath.row - realIndexPath.row);
        NSMutableIndexSet *deleteRows = [NSMutableIndexSet indexSetWithIndexesInRange:range];
        [deleteRows removeIndexes:hiddenForums];
        [hiddenForums addIndexesInRange:range];
        for (NSUInteger i = 0; i < deleteRows.count; i++) {
            NSIndexPath *deleteIndexPath = [NSIndexPath indexPathForRow:indexPath.row + i + 1
                                                              inSection:indexPath.section];
            [self.delegate forumTreeController:self
                       visibleForumAtIndexPath:deleteIndexPath
                                     didChange:AwfulForumTreeControllerChangeTypeDelete];
        }
    }
    [self.delegate forumTreeControllerDidUpdate:self];
}

#pragma mark NSFetchedResultsControllerDelegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.delegate forumTreeControllerWillUpdate:self];
    _newlyInsertedSections = [NSMutableIndexSet new];
}

- (void)controller:(NSFetchedResultsController *)controller
  didChangeSection:(id <NSFetchedResultsSectionInfo>)section
           atIndex:(NSUInteger)index
     forChangeType:(NSFetchedResultsChangeType)type
{
    if (type == NSFetchedResultsChangeInsert) {
        // This method can be called out of order when a batch of sections are inserted, so pad the array of hidden forums sets.
        for (NSUInteger i = _hiddenForumsInCategory.count; i <= index; i++) {
            [_hiddenForumsInCategory addObject:[NSNull null]];
        }
        
        // We need a fully-initialized set of hidden forums so we can correctly compute the visible index path as the rows are inserted.
        NSMutableIndexSet *hiddenForums = [self initialHiddenForumsWithSection:section];
        
        // Remember that we've done this so we don't update the hidden forums set a second time.
        [_newlyInsertedSections addIndex:index];
        
        if ([_hiddenForumsInCategory[index] isEqual:[NSNull null]]) {
            [_hiddenForumsInCategory replaceObjectAtIndex:index withObject:hiddenForums];
        } else {
            [_hiddenForumsInCategory insertObject:hiddenForums atIndex:index];
        }
        [self.delegate forumTreeController:self
                           categoryAtIndex:index
                                 didChange:AwfulForumTreeControllerChangeTypeInsert];
    } else if (type == NSFetchedResultsChangeDelete) {
        [_hiddenForumsInCategory removeObjectAtIndex:index];
        [self.delegate forumTreeController:self
                           categoryAtIndex:index
                                 didChange:AwfulForumTreeControllerChangeTypeInsert];
    }
}

- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(AwfulForum *)forum
       atIndexPath:(NSIndexPath *)indexPath
     forChangeType:(NSFetchedResultsChangeType)changeType
      newIndexPath:(NSIndexPath *)newIndexPath
{
    switch (changeType) {
        case NSFetchedResultsChangeDelete: {
            NSIndexPath *visibleIndexPath = [self indexPathForVisibleForum:forum];
            NSMutableIndexSet *hiddenForums = _hiddenForumsInCategory[indexPath.section];
            [hiddenForums shiftIndexesStartingAtIndex:(indexPath.row + 1) by:-1];
            if (visibleIndexPath) {
                [self.delegate forumTreeController:self
                           visibleForumAtIndexPath:visibleIndexPath
                                         didChange:AwfulForumTreeControllerChangeTypeDelete];
            }
            break;
        }
            
        case NSFetchedResultsChangeInsert: {
            
            // The hidden forums set is already up-to-date for new sections.
            if (![_newlyInsertedSections containsIndex:newIndexPath.section]) {
                NSMutableIndexSet *hiddenForums = _hiddenForumsInCategory[newIndexPath.section];
                [hiddenForums shiftIndexesStartingAtIndex:newIndexPath.row by:1];
                if (forum.parentForum) {
                    [hiddenForums addIndex:newIndexPath.row];
                }
            }
            
            NSIndexPath *visibleIndexPath = [self indexPathForVisibleForum:forum];
            if (visibleIndexPath) {
                [self.delegate forumTreeController:self
                           visibleForumAtIndexPath:visibleIndexPath
                                         didChange:AwfulForumTreeControllerChangeTypeInsert];
            }
            break;
        }
            
        case NSFetchedResultsChangeMove:
            [self controller:controller
             didChangeObject:forum
                 atIndexPath:indexPath
               forChangeType:NSFetchedResultsChangeDelete
                newIndexPath:nil];
            [self controller:controller
             didChangeObject:forum
                 atIndexPath:nil
               forChangeType:NSFetchedResultsChangeInsert
                newIndexPath:newIndexPath];
            break;
            
        case NSFetchedResultsChangeUpdate: {
            NSIndexPath *visibleIndexPath = [self indexPathForVisibleForum:forum];
            if (visibleIndexPath) {
                [self.delegate forumTreeController:self
                           visibleForumAtIndexPath:visibleIndexPath
                                         didChange:AwfulForumTreeControllerChangeTypeUpdate];
            }
            break;
        }
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.delegate forumTreeControllerDidUpdate:self];
    _newlyInsertedSections = nil;
}

@end
