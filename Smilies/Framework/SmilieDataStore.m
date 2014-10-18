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
                                                                             options:@{NSMigratePersistentStoresAutomaticallyOption: @YES,
                                                                                       NSInferMappingModelAutomaticallyOption: @YES}
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
