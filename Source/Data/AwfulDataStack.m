//  AwfulDataStack.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulDataStack.h"

@implementation AwfulDataStack
{
    NSURL *_storeURL;
    NSURL *_modelURL;
}

- (id)initWithStoreURL:(NSURL *)storeURL modelURL:(NSURL *)modelURL
{
    if (!(self = [super init])) return nil;
    _storeURL = storeURL;
    _modelURL = modelURL;
    _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:_modelURL];
    _managedObjectContext.persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    [self addPersistentStore];
    return self;
}

- (void)addPersistentStore
{
    NSError *error;
    NSPersistentStore *store;
    NSDictionary *options = @{ NSMigratePersistentStoresAutomaticallyOption: @YES,
                               NSInferMappingModelAutomaticallyOption: @YES };
    store = [_managedObjectContext.persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                                           configuration:nil
                                                                                     URL:_storeURL
                                                                                 options:options
                                                                                   error:&error];
    if (!store) {
        if ([error.domain isEqualToString:NSCocoaErrorDomain] && error.code == NSMigrationMissingSourceModelError) {
            NSLog(@"%s automatic migration failed", __PRETTY_FUNCTION__);
            [self deleteStoreAndResetStack];
            return;
        }
        NSLog(@"%s error adding %@: %@", __PRETTY_FUNCTION__, _storeURL, error);
    }
}

- (id)init
{
    return [self initWithStoreURL:nil modelURL:nil];
}

- (void)deleteStoreAndResetStack
{
    NSPersistentStoreCoordinator *persistentStoreCoordinator = _managedObjectContext.persistentStoreCoordinator;
    NSFileManager *fileManager = [NSFileManager new];
    NSError *error;
    BOOL ok;
    for (NSPersistentStore *store in persistentStoreCoordinator.persistentStores) {
        ok = [persistentStoreCoordinator removePersistentStore:store error:&error];
        if (!ok) {
            NSLog(@"%s error removing store at %@: %@", __PRETTY_FUNCTION__, store.URL, error);
        }
        if (![store.URL isEqual:_storeURL]) {
            ok = [fileManager removeItemAtURL:store.URL error:&error];
            if (!ok) {
                NSLog(@"%s error deleting store at %@: %@", __PRETTY_FUNCTION__, store.URL, error);
            }
        }
    }
    ok = [fileManager removeItemAtURL:_storeURL error:&error];
    if (!ok) {
        NSLog(@"%s error deleting main store at %@: %@", __PRETTY_FUNCTION__, _storeURL, error);
    }
    [self addPersistentStore];
}

@end
