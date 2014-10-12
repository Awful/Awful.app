//  SmilieDataStore.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SmilieDataStore.h"
#import "SmilieAppContainer.h"
#import "SmilieMetadata.h"

@interface SmilieDataStore ()

@property (strong, nonatomic) NSPersistentStoreCoordinator *storeCoordinator;
@property (strong, nonatomic) NSPersistentStore *bundledSmilieStore;
@property (strong, nonatomic) NSPersistentStore *appContainerSmilieStore;
@property (strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@end

@implementation SmilieDataStore

- (NSManagedObjectContext *)managedObjectContext
{
    if (!_managedObjectContext) {
        
        // Make sure the stores are loaded.
        [self bundledSmilieStore];
        [self appContainerSmilieStore];
        
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        _managedObjectContext.persistentStoreCoordinator = self.storeCoordinator;
        
        #if DEBUG || AWFUL_BETA
        {{
            // Awful 3.1 beta 3 allowed one to add a favorite smilie but did not order the favorites. This little fix detects that scenario and sets an arbitrary but persistent ordering.
            NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:[SmilieMetadata entityName]];
            fetchRequest.predicate = [NSPredicate predicateWithFormat:@"isFavorite = YES AND favoriteIndex = 0"];
            NSError *error;
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

- (NSPersistentStoreCoordinator *)storeCoordinator
{
    if (!_storeCoordinator) {
        NSManagedObjectModel *model = [[self class] managedObjectModel];
        _storeCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    }
    return _storeCoordinator;
}

- (NSPersistentStore *)bundledSmilieStore
{
    if (!_bundledSmilieStore) {
        NSError *error;
        _bundledSmilieStore = [self.storeCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                                  configuration:@"NoMetadata"
                                                                            URL:BundledSmilieStoreURL()
                                                                        options:@{NSReadOnlyPersistentStoreOption: @YES}
                                                                          error:&error];
        if (!_bundledSmilieStore) {
            NSLog(@"%s error adding bundled store: %@", __PRETTY_FUNCTION__, error);
        }
    }
    return _bundledSmilieStore;
}

- (NSPersistentStore *)appContainerSmilieStore
{
    if (!_appContainerSmilieStore) {
        NSError *error;
        _appContainerSmilieStore = [self.storeCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                                       configuration:nil
                                                                                 URL:AppContainerSmilieStoreURL()
                                                                             options:nil
                                                                               error:&error];
        if (!_appContainerSmilieStore) {
            NSLog(@"%s error adding app container store: %@", __PRETTY_FUNCTION__, error);
        }
    }
    return _appContainerSmilieStore;
}

static NSURL * BundledSmilieStoreURL(void)
{
    return [[NSBundle bundleForClass:[SmilieDataStore class]] URLForResource:@"Smilies" withExtension:@"sqlite"];
}

static NSURL * AppContainerSmilieStoreURL(void)
{
    NSURL *folder = [SmilieKeyboardSharedContainerURL() URLByAppendingPathComponent:@"Data Store"];
    NSError *error;
    if (![[NSFileManager defaultManager] createDirectoryAtURL:folder withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"%s error creating containing folder: %@", __PRETTY_FUNCTION__, error);
    }
    return [folder URLByAppendingPathComponent:@"Smilies.sqlite"];
}

+ (NSManagedObjectModel *)managedObjectModel
{
    NSURL *modelURL = [[NSBundle bundleForClass:[SmilieDataStore class]] URLForResource:@"Smilies" withExtension:@"momd"];
    return [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
}

@end

NSString * const SmilieMetadataVersionKey = @"SmilieVersion";
NSString * const SmilieLastSuccessfulScrapeDateKey = @"SmilieLastSuccessfulScrape";
