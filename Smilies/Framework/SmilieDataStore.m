//  SmilieDataStore.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SmilieDataStore.h"
#import "SmilieAppContainer.h"
#import "SmilieMetadata.h"

@implementation SmilieDataStore

@synthesize managedObjectContext = _managedObjectContext;

- (NSManagedObjectContext *)managedObjectContext
{
    if (!_managedObjectContext) {
        NSManagedObjectModel *model = [[self class] managedObjectModel];
        NSPersistentStoreCoordinator *storeCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
        NSDictionary *options = @{NSReadOnlyPersistentStoreOption: @YES};
        NSError *error;
        if (![storeCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:@"NoMetadata" URL:[[self class] bundledSmilieStoreURL] options:options error:&error]) {
            NSLog(@"%s error adding bundled store: %@", __PRETTY_FUNCTION__, error);
        }
        if (![storeCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:[[self class] appContainerSmilieStoreURL] options:nil error:&error]) {
            NSLog(@"%s error adding app container store: %@", __PRETTY_FUNCTION__, error);
        }
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        _managedObjectContext.persistentStoreCoordinator = storeCoordinator;
        
        #if DEBUG || AWFUL_BETA
        {{
            // Awful 3.1 beta 3 allowed one to add a favorite smilie but did not order the favorites. This little fix detects that scenario and sets an arbitrary but persistent ordering.
            NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[SmilieMetadata entityName]];
            fetchRequest.predicate = [NSPredicate predicateWithFormat:@"isFavorite = YES AND favoriteIndex = 0"];
            NSUInteger unorderedFavoritesCount = [_managedObjectContext countForFetchRequest:fetchRequest error:&error];
            NSAssert(unorderedFavoritesCount != NSNotFound, @"error fetching unordered favorite count: %@", error);
            if (unorderedFavoritesCount > 1) {
                fetchRequest.predicate = [NSPredicate predicateWithFormat:@"isFavorite = YES"];
                fetchRequest.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"favoriteIndex" ascending:YES]];
                NSArray *allFavorites = [_managedObjectContext executeFetchRequest:fetchRequest error:&error];
                NSAssert(allFavorites, @"error fetching all favorites: %@", error);
                [allFavorites enumerateObjectsUsingBlock:^(SmilieMetadata *metadata, NSUInteger i, BOOL *stop) {
                    metadata.favoriteIndex = i;
                }];
                if (![_managedObjectContext save:&error]) {
                    NSLog(@"%s error saving: %@", __PRETTY_FUNCTION__, error);
                }
            }
        }}
        #else
            #error Remove this beta code before submitting to the App Store!
        #endif
    }
    return _managedObjectContext;
}

+ (NSManagedObjectModel *)managedObjectModel
{
    NSURL *modelURL = [[NSBundle bundleForClass:[SmilieDataStore class]] URLForResource:@"Smilies" withExtension:@"momd"];
    return [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
}

+ (NSURL *)bundledSmilieStoreURL
{
    return [[NSBundle bundleForClass:[SmilieDataStore class]] URLForResource:@"Smilies" withExtension:@"sqlite"];
}

+ (NSURL *)appContainerSmilieStoreURL
{
    NSURL *folder = [SmilieKeyboardSharedContainerURL() URLByAppendingPathComponent:@"Data Store"];
    NSError *error;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"%s error creating containing folder: %@", __PRETTY_FUNCTION__, error);
    }
    return [folder URLByAppendingPathComponent:@"Smilies.sqlite"];
}

@end
