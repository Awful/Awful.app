//  SmilieFetchedDataSource.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SmilieFetchedDataSource.h"
@import CoreData;
#import <FLAnimatedImage/FLAnimatedImage.h>
@import MobileCoreServices;
#import "Smilie.h"
#import "SmilieDataStore.h"
@import UIKit;

@interface SmilieFetchedDataSource () <NSFetchedResultsControllerDelegate>

@property (weak, nonatomic) UICollectionView *collectionView;
@property (strong, nonatomic) NSFetchedResultsController *fetchedResultsController;

@end

@implementation SmilieFetchedDataSource

- (instancetype)initWithDataStore:(SmilieDataStore *)dataStore
{
    if ((self = [super init])) {
        _dataStore = dataStore;
    }
    return self;
}

- (NSFetchedResultsController *)fetchedResultsController
{
    if (!_fetchedResultsController) {
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[Smilie entityName]];
        fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"section" ascending:YES],
                                         [NSSortDescriptor sortDescriptorWithKey:@"text" ascending:YES]];
        NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        context.parentContext = self.dataStore.managedObjectContext;
        _fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                        managedObjectContext:context
                                                                          sectionNameKeyPath:@"section"
                                                                                   cacheName:nil];
        _fetchedResultsController.delegate = self;
        
        NSError *error;
        if (![_fetchedResultsController performFetch:&error]) {
            NSLog(@"%s could not fetch smilies: %@", __PRETTY_FUNCTION__, error);
        }
    }
    return _fetchedResultsController;
}

- (Smilie *)smilieAtIndexPath:(NSIndexPath *)indexPath
{
    return [self.fetchedResultsController objectAtIndexPath:indexPath];
}

#pragma mark - SmilieKeyboardDataSource

- (NSInteger)numberOfSectionsInSmilieKeyboard:(SmilieKeyboardView *)keyboardView
{
    return self.fetchedResultsController.sections.count;
}

- (NSInteger)smilieKeyboard:(SmilieKeyboardView *)keyboardView numberOfSmiliesInSection:(NSInteger)section
{
    return [self.fetchedResultsController.sections[section] numberOfObjects];
}

- (CGSize)smilieKeyboard:(SmilieKeyboardView *)keyboardView sizeOfSmilieAtIndexPath:(NSIndexPath *)indexPath
{
    Smilie *smilie = [self.fetchedResultsController objectAtIndexPath:indexPath];
    return smilie.imageSize;
}

- (id)smilieKeyboard:(SmilieKeyboardView *)keyboardView imageOfSmilieAtIndexPath:(NSIndexPath *)indexPath
{
    Smilie *smilie = [self.fetchedResultsController objectAtIndexPath:indexPath];
    if (UTTypeConformsTo((__bridge CFStringRef)smilie.imageUTI, kUTTypeGIF)) {
        return [[FLAnimatedImage alloc] initWithAnimatedGIFData:smilie.imageData];
    } else {
        return [UIImage imageWithData:smilie.imageData];
    }
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.collectionView reloadData];
}

@end
