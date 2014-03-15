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
        if ([error.domain isEqualToString:NSCocoaErrorDomain] && error.code == NSFileReadCorruptFileError) {
            CLSNSLog(@"%s corrupt database (mismatched store and write-ahead log?): %@", __PRETTY_FUNCTION__, error);
            [self deleteStoreAndResetStack];
            return;
        }
        
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

- (BOOL)isInMemoryStore
{
    return !!_storeURL;
}

- (void)deleteStoreAndResetStack
{
    CLSLog(@"%s it's happening", __PRETTY_FUNCTION__);
    NSPersistentStoreCoordinator *persistentStoreCoordinator = _managedObjectContext.persistentStoreCoordinator;
    for (NSPersistentStore *store in persistentStoreCoordinator.persistentStores) {
        NSError *error;
        BOOL ok = [persistentStoreCoordinator removePersistentStore:store error:&error];
        if (!ok) {
            CLSNSLog(@"%s error removing store at %@: %@", __PRETTY_FUNCTION__, store.URL, error);
        }
        
        if (_storeURL && ![store.URL isEqual:_storeURL]) {
            DeleteDataStoreAtURL(store.URL);
        }
    }
    if (_storeURL) {
        DeleteDataStoreAtURL(_storeURL);
    }
    
    [self addPersistentStore];
    CLSLog(@"%s it's done", __PRETTY_FUNCTION__);
}

void DeleteDataStoreAtURL(NSURL *storeURL)
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    BOOL ok = [[NSFileManager defaultManager] removeItemAtURL:storeURL error:&error];
    if (!ok) {
        CLSNSLog(@"%s error deleting SQLite store at %@: %@", __PRETTY_FUNCTION__, storeURL, error);
    }

    NSURL *directory = [storeURL URLByDeletingLastPathComponent];
    NSArray *possibleDetritus = [fileManager contentsOfDirectoryAtURL:directory includingPropertiesForKeys:nil options:0 error:nil];
    NSString *extension = storeURL.pathExtension;
    NSArray *extensionsToDelete = @[ [extension stringByAppendingString:@"-shm"],
                                     [extension stringByAppendingString:@"-wal"] ];
    for (NSURL *detritusURL in possibleDetritus) {
        if ([detritusURL.path hasPrefix:storeURL.path] && [extensionsToDelete containsObject:detritusURL.pathExtension]) {
            NSError *error;
            BOOL ok = [fileManager removeItemAtURL:detritusURL error:&error];
            if (!ok) {
                CLSNSLog(@"%s error deleting SQLite store detritus at %@: %@", __PRETTY_FUNCTION__, detritusURL, error);
            }
        }
    }
}

@end
