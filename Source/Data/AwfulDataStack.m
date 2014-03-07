//  AwfulDataStack.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulDataStack.h"
#ifndef DEBUG
    #import <Crashlytics/Crashlytics.h>
#else
    #define CLSLog NSLog
    #define CLSNSLog NSLog
#endif

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
    CLSLog(@"%s it's happening", __PRETTY_FUNCTION__);
    NSError *error;
    NSPersistentStore *store;
    NSDictionary *options = @{ NSMigratePersistentStoresAutomaticallyOption: @YES,
                               NSInferMappingModelAutomaticallyOption: @YES };
    NSString *storeType = _storeURL ? NSSQLiteStoreType : NSInMemoryStoreType;
    store = [_managedObjectContext.persistentStoreCoordinator addPersistentStoreWithType:storeType
                                                                           configuration:nil
                                                                                     URL:_storeURL
                                                                                 options:options
                                                                                   error:&error];
    if (!store) {
        if ([error.domain isEqualToString:NSCocoaErrorDomain] && (error.code == NSMigrationMissingSourceModelError ||
                                                                  error.code == NSMigrationMissingMappingModelError)) {
            CLSNSLog(@"%s automatic migration failed", __PRETTY_FUNCTION__);
            [self deleteStoreAndResetStack];
            return;
        }
        CLSNSLog(@"%s error adding %@: %@", __PRETTY_FUNCTION__, _storeURL, error);
    }
    CLSLog(@"%s it's done", __PRETTY_FUNCTION__);
}

- (id)init
{
    return [self initWithStoreURL:nil modelURL:nil];
}

- (void)deleteStoreAndResetStack
{
    CLSLog(@"%s it's happening", __PRETTY_FUNCTION__);
    NSPersistentStoreCoordinator *persistentStoreCoordinator = _managedObjectContext.persistentStoreCoordinator;
    NSFileManager *fileManager = [NSFileManager new];
    NSError *error;
    BOOL ok;
    for (NSPersistentStore *store in persistentStoreCoordinator.persistentStores) {
        ok = [persistentStoreCoordinator removePersistentStore:store error:&error];
        if (!ok) {
            CLSNSLog(@"%s error removing store at %@: %@", __PRETTY_FUNCTION__, store.URL, error);
        }
        if (_storeURL && ![store.URL isEqual:_storeURL]) {
            ok = [fileManager removeItemAtURL:store.URL error:&error];
            if (!ok) {
                CLSNSLog(@"%s error deleting store at %@: %@", __PRETTY_FUNCTION__, store.URL, error);
            }
        }
    }
    if (_storeURL) {
        ok = [fileManager removeItemAtURL:_storeURL error:&error];
        if (!ok) {
            CLSNSLog(@"%s error deleting main store at %@: %@", __PRETTY_FUNCTION__, _storeURL, error);
        }
    }
    [self addPersistentStore];
    CLSLog(@"%s it's done", __PRETTY_FUNCTION__);
}

@end
