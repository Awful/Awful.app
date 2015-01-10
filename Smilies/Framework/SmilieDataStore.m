//  SmilieDataStore.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SmilieDataStore.h"
#import "SmilieAppContainer.h"
#import "SmilieMetadata.h"

@implementation SmilieDataStore

- (instancetype)init
{
    if ((self = [super init])) {
        NSManagedObjectModel *model = [[self class] managedObjectModel];
        _storeCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
        
        [self addStores];
        
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        _managedObjectContext.persistentStoreCoordinator = self.storeCoordinator;
    }
    return self;
}

- (void)addStores
{
    // This silly dance (addStores along with addBundledSmilieStore) provides a hook for testing. Since a data store might get accessed by multiple threads, it needs its stores and context to be ready to go after initialization -- careless lazy-loading won't cut it.
    
    [self addBundledSmilieStore];
    
    NSError *error;
    _appContainerSmilieStore = [self.storeCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                                   configuration:nil
                                                                             URL:AppContainerSmilieStoreURL()
                                                                         options:@{NSMigratePersistentStoresAutomaticallyOption: @YES,
                                                                                   NSInferMappingModelAutomaticallyOption: @YES}
                                                                           error:&error];
    if (!_appContainerSmilieStore) {
        NSLog(@"%s error adding app container store: %@", __PRETTY_FUNCTION__, error);
        return;
    }
}

- (void)addBundledSmilieStore
{
    NSError *error;
    _bundledSmilieStore = [_storeCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                          configuration:@"NoMetadata"
                                                                    URL:BundledSmilieStoreURL()
                                                                options:@{NSReadOnlyPersistentStoreOption: @YES}
                                                                  error:&error];
    if (!_bundledSmilieStore) {
        NSLog(@"%s error adding bundled store: %@", __PRETTY_FUNCTION__, error);
    }
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
