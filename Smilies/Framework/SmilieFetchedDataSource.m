//  SmilieFetchedDataSource.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SmilieFetchedDataSource.h"
@import CoreData;
#import <FLAnimatedImage/FLAnimatedImage.h>
@import MobileCoreServices;
#import "Smilie.h"
#import "SmilieDataStore.h"
#import "SmilieMetadata.h"
@import UIKit;

@interface SmilieFetchedDataSource () <NSFetchedResultsControllerDelegate>

@property (weak, nonatomic) UICollectionView *collectionView;
@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;

@property (strong, nonatomic) NSMutableArray *updateBlocks;
@property (assign, nonatomic) BOOL ignoringUpdates;

@end

@implementation SmilieFetchedDataSource

@synthesize smilieList = _smilieList;

@synthesize fetchedResultsController = _fetchedResultsController;

- (instancetype)initWithDataStore:(SmilieDataStore *)dataStore
{
    if ((self = [super init])) {
        _dataStore = dataStore;
    }
    return self;
}

- (void)setSmilieList:(SmilieList)smilieList
{
    if (_smilieList != smilieList) {
        _smilieList = smilieList;
        self.fetchedResultsController = nil;
        [self.collectionView reloadData];
    }
}

- (NSFetchedResultsController *)fetchedResultsController
{
    if (!_fetchedResultsController) {
        NSFetchedResultsController *fetchedResultsController;
        switch (self.smilieList) {
            case SmilieListAll: {
                NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[Smilie entityName]];
                fetchRequest.predicate = [NSPredicate predicateWithFormat:@"imageData != nil"];
                fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"section" ascending:YES],
                                                 [NSSortDescriptor sortDescriptorWithKey:@"text" ascending:YES]];
                fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                               managedObjectContext:self.dataStore.managedObjectContext
                                                                                 sectionNameKeyPath:@"section"
                                                                                          cacheName:nil];
                break;
            }
                
            case SmilieListRecent: {
                NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[SmilieMetadata entityName]];
                fetchRequest.predicate = [NSPredicate predicateWithFormat:@"lastUsedDate != nil"];
                fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"lastUsedDate" ascending:NO]];
                fetchRequest.fetchLimit = 40;
                fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                               managedObjectContext:self.dataStore.managedObjectContext
                                                                                 sectionNameKeyPath:nil
                                                                                          cacheName:nil];
                break;
            }
                
            case SmilieListFavorites: {
                NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[SmilieMetadata entityName]];
                fetchRequest.predicate = [NSPredicate predicateWithFormat:@"isFavorite = YES"];
                fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"favoriteIndex" ascending:YES]];
                fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                               managedObjectContext:self.dataStore.managedObjectContext
                                                                                 sectionNameKeyPath:nil
                                                                                          cacheName:nil];
                break;
            }
        }
        self.fetchedResultsController = fetchedResultsController;
    }
    return _fetchedResultsController;
}

- (void)setFetchedResultsController:(NSFetchedResultsController *)fetchedResultsController
{
    if (fetchedResultsController != _fetchedResultsController) {
        _fetchedResultsController.delegate = nil;
        self.updateBlocks = nil;
    }
    
    _fetchedResultsController = fetchedResultsController;
    fetchedResultsController.delegate = self;
    
    if (fetchedResultsController) {
        NSError *error;
        if (![fetchedResultsController performFetch:&error]) {
            NSLog(@"%s could not fetch smilies: %@", __PRETTY_FUNCTION__, error);
        }
    }
}

- (Smilie *)smilieAtIndexPath:(NSIndexPath *)indexPath
{
    NSString *entityName = self.fetchedResultsController.fetchRequest.entityName;
    if ([entityName isEqualToString:[Smilie entityName]]) {
        return [self.fetchedResultsController objectAtIndexPath:indexPath];
    } else if ([entityName isEqualToString:[SmilieMetadata entityName]]) {
        SmilieMetadata *metadata = [self.fetchedResultsController objectAtIndexPath:indexPath];
        return metadata.smilie;
    } else {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException reason:@"unexpected entity name" userInfo:nil];
    }
}

#pragma mark - SmilieKeyboardDataSource

- (NSInteger)numberOfSectionsInSmilieKeyboard:(SmilieKeyboardView *)keyboardView
{
    self.collectionView = keyboardView.collectionView;
    return self.fetchedResultsController.sections.count;
}

- (NSInteger)smilieKeyboard:(SmilieKeyboardView *)keyboardView numberOfSmiliesInSection:(NSInteger)section
{
    return [self.fetchedResultsController.sections[section] numberOfObjects];
}

- (CGSize)smilieKeyboard:(SmilieKeyboardView *)keyboardView sizeOfSmilieAtIndexPath:(NSIndexPath *)indexPath
{
    Smilie *smilie = [self smilieAtIndexPath:indexPath];
    return smilie.imageSize;
}

- (void)smilieKeyboard:(SmilieKeyboardView *)keyboardView deleteSmilieAtIndexPath:(NSIndexPath *)indexPath
{
    NSAssert(self.smilieList == SmilieListFavorites, @"only favorites can be deleted");
    
    SmilieMetadata *metadata = [self.fetchedResultsController objectAtIndexPath:indexPath];
    [metadata removeFromFavoritesUpdatingSubsequentIndices];
    NSError *error;
    if (![metadata.managedObjectContext save:&error]) {
        NSLog(@"%s error saving: %@", __PRETTY_FUNCTION__, error);
    }
}

- (void)smilieKeyboard:(SmilieKeyboardView *)keyboardView dragSmilieFromIndexPath:(NSIndexPath *)oldIndexPath toIndexPath:(NSIndexPath *)newIndexPath
{
    NSAssert(self.smilieList == SmilieListFavorites, @"only favorites can be moved");
    
    self.ignoringUpdates = YES; {
        id<NSFetchedResultsSectionInfo> section = self.fetchedResultsController.sections[0];
        NSInteger delta = oldIndexPath.item < newIndexPath.item ? -1 : 1;
        for (NSInteger i = MIN(oldIndexPath.item, newIndexPath.item), end = MAX(oldIndexPath.item, newIndexPath.item); i <= end; i++) {
            SmilieMetadata *metadata = section.objects[i];
            metadata.favoriteIndex += delta;
        }
        
        SmilieMetadata *metadata = [self.fetchedResultsController objectAtIndexPath:oldIndexPath];
        metadata.favoriteIndex = newIndexPath.item;
        
        [metadata.managedObjectContext processPendingChanges];
    }
    self.ignoringUpdates = NO;
}

- (void)smilieKeyboard:(SmilieKeyboardView *)keyboardView didFinishDraggingSmilieToIndexPath:(NSIndexPath *)indexPath
{
    NSError *error;
    if (![self.dataStore.managedObjectContext save:&error]) {
        NSLog(@"%s error saving: %@", __PRETTY_FUNCTION__, error);
    }
}

- (id)smilieKeyboard:(SmilieKeyboardView *)keyboardView imageOfSmilieAtIndexPath:(NSIndexPath *)indexPath
{
    Smilie *smilie = [self smilieAtIndexPath:indexPath];
    id image;
    if (UTTypeConformsTo((__bridge CFStringRef)smilie.imageUTI, kUTTypeGIF)) {
        image = [[FLAnimatedImage alloc] initWithAnimatedGIFData:smilie.imageData];
    } else {
        image = [UIImage imageWithData:smilie.imageData];
    }
    [image setAccessibilityLabel:smilie.text];
    return image;
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    switch (self.smilieList) {
        case SmilieListAll:
        case SmilieListFavorites:
            if (!self.ignoringUpdates) {
                self.updateBlocks = [NSMutableArray new];
            }
            break;
            
        case SmilieListRecent:
            // Don't bother with the recent list, otherwise smilies will fly around.
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id<NSFetchedResultsSectionInfo>)sectionInfo atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)changeType
{
    __weak UICollectionView *collectionView = self.collectionView;
    if (changeType == NSFetchedResultsChangeInsert) {
        [self.updateBlocks addObject:^{
            [collectionView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex]];
        }];
    } else if (changeType == NSFetchedResultsChangeDelete) {
        [self.updateBlocks addObject:^{
            [collectionView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex]];
        }];
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)changeType newIndexPath:(NSIndexPath *)newIndexPath
{
    __weak UICollectionView *collectionView = self.collectionView;
    switch (changeType) {
        case NSFetchedResultsChangeDelete: {
            [self.updateBlocks addObject:^{
                [collectionView deleteItemsAtIndexPaths:@[indexPath]];
            }];
            break;
        }
            
        case NSFetchedResultsChangeInsert: {
            [self.updateBlocks addObject:^{
                [collectionView insertItemsAtIndexPaths:@[newIndexPath]];
            }];
            break;
        }
            
        case NSFetchedResultsChangeMove: {
            [self.updateBlocks addObject:^{
                [collectionView moveItemAtIndexPath:indexPath toIndexPath:newIndexPath];
            }];
            break;
        }
        
        case NSFetchedResultsChangeUpdate: {
            [self.updateBlocks addObject:^{
                [collectionView reloadItemsAtIndexPaths:@[indexPath]];
            }];
            break;
        }
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    NSArray *updateBlocks = self.updateBlocks;
    self.updateBlocks = nil;
    if (updateBlocks.count > 0) {
        [self.collectionView performBatchUpdates:^{
            for (void (^block)(void) in updateBlocks) {
                block();
            }
        } completion:nil];
    }

}

@end
