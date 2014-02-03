//  AwfulForumTreeController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulForumTreeController.h"

@interface AwfulForumTreeController () <NSFetchedResultsControllerDelegate>

@end

@implementation AwfulForumTreeController
{
    NSFetchedResultsController *_frc;
    NSMutableArray *_hiddenForumsInCategory;
    NSMutableIndexSet *_newlyInsertedSections;
}


- (id)initWithManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    if (!(self = [super init])) return nil;
    _managedObjectContext = managedObjectContext;
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[AwfulForum entityName]];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"category != nil"];
    fetchRequest.sortDescriptors = @[ [NSSortDescriptor sortDescriptorWithKey:@"category.index" ascending:YES],
                                      [NSSortDescriptor sortDescriptorWithKey:@"index" ascending:YES] ];
    _frc = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                               managedObjectContext:_managedObjectContext
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
        [_hiddenForumsInCategory addObject:[self hiddenForumsInSection:section]];
    }
    return self;
}

- (NSIndexSet *)hiddenForumsInSection:(id <NSFetchedResultsSectionInfo>)section
{
	NSMutableIndexSet *hiddenForums = [NSMutableIndexSet new];
    [section.objects enumerateObjectsUsingBlock:^(AwfulForum *forum, NSUInteger i, BOOL *stop) {
		
		while (forum != nil) {
			forum = forum.parentForum;
			
			if (forum && !forum.childrenExpanded) {
				[hiddenForums addIndex:i];
				break;
			}
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
    AwfulForum *forum = [_frc objectAtIndexPath:realIndexPath];
    return forum.childrenExpanded;
}

- (void)toggleVisibleForumExpandedAtIndexPath:(NSIndexPath *)indexPath
{
    AwfulForum *forum = [self visibleForumAtIndexPath:indexPath];
    if (forum.children.count == 0) {
        return;
    }
	
	//Toggle the forum's children being hidden
	forum.childrenExpanded = !forum.childrenExpanded;	
	
	id <NSFetchedResultsSectionInfo> section = _frc.sections[indexPath.section];
	
	NSIndexSet *oldHiddenForums = _hiddenForumsInCategory[indexPath.section];
    NSIndexSet *newHiddenForums = [self hiddenForumsInSection:section];
	_hiddenForumsInCategory[indexPath.section] = newHiddenForums; //Update the cached hidden forums set for this section
	
	
	NSMutableIndexSet *visibleForums = [[[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, section.objects.count)] indexesPassingTest:^BOOL(NSUInteger idx, BOOL *stop) {
		
		return ![oldHiddenForums containsIndex:idx];
		
	}] mutableCopy];
	
	
	//Begin delegate update
	[self.delegate forumTreeControllerWillUpdate:self];
	
	
	//Add all forums that were hidden and aren't any longer
	NSIndexSet *addedIndexes = [oldHiddenForums indexesPassingTest:^BOOL(NSUInteger idx, BOOL *stop) {
		return ![newHiddenForums containsIndex:idx];
	}];
	
	[addedIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
		
		NSUInteger visbleForumsBelow = [visibleForums countOfIndexesInRange:NSMakeRange(0, idx)];
		
		NSIndexPath *insertIndexPath = [NSIndexPath indexPathForRow:visbleForumsBelow
														  inSection:indexPath.section];
		
		[visibleForums addIndex:idx];
		
		[self.delegate forumTreeController:self
				   visibleForumAtIndexPath:insertIndexPath
								 didChange:AwfulForumTreeControllerChangeTypeInsert];
		
	}];
	
	
	//Remove all forums that were visible and are now being hidden
	NSIndexSet *removedIndexes = [newHiddenForums indexesPassingTest:^BOOL(NSUInteger idx, BOOL *stop) {
		return ![oldHiddenForums containsIndex:idx];
	}];
	
	[removedIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
		
		NSUInteger visbleForumsBelow = [visibleForums countOfIndexesInRange:NSMakeRange(0, idx)];
		
		
		NSIndexPath *removeIndexPath = [NSIndexPath indexPathForRow:visbleForumsBelow
														  inSection:indexPath.section];
		
		[self.delegate forumTreeController:self
				   visibleForumAtIndexPath:removeIndexPath
								 didChange:AwfulForumTreeControllerChangeTypeDelete];
		
	}];
		
	//End delegate update
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
        NSIndexSet *hiddenForums = [self hiddenForumsInSection:section];
        
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
                                 didChange:AwfulForumTreeControllerChangeTypeDelete];
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
            if (visibleIndexPath) {
                [self.delegate forumTreeController:self
                           visibleForumAtIndexPath:visibleIndexPath
                                         didChange:AwfulForumTreeControllerChangeTypeDelete];
            }
            break;
        }
            
        case NSFetchedResultsChangeInsert: {
			
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
	
	
	switch (changeType) {
		case NSFetchedResultsChangeDelete:
        case NSFetchedResultsChangeInsert:
        case NSFetchedResultsChangeMove:
			_hiddenForumsInCategory[indexPath.section] = [self hiddenForumsInSection:_frc.sections[indexPath.section]];

		default:
			break;
	}
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.delegate forumTreeControllerDidUpdate:self];
    _newlyInsertedSections = nil;
}

@end
