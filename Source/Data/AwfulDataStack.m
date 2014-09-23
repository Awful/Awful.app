//  AwfulDataStack.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulDataStack.h"
#import <objc/runtime.h>

static void *DataStackKey = &DataStackKey;

@implementation AwfulDataStack
{
    NSURL *_storeURL;
    NSURL *_modelURL;
}

- (id)initWithStoreURL:(NSURL *)storeURL modelURL:(NSURL *)modelURL
{
    if ((self = [super init])) {
        _storeURL = storeURL;
        _modelURL = modelURL;
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        objc_setAssociatedObject(_managedObjectContext, DataStackKey, self, OBJC_ASSOCIATION_ASSIGN);
        NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:_modelURL];
        _managedObjectContext.persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
        [self addPersistentStore];
    }
    return self;
}

- (void)addPersistentStore
{
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
            NSLog(@"%s corrupt database (mismatched store and write-ahead log?): %@", __PRETTY_FUNCTION__, error);
            [self deleteStoreAndResetStack];
            return;
        }
        
        if ([error.domain isEqualToString:NSCocoaErrorDomain] && (error.code == NSMigrationMissingSourceModelError ||
                                                                  error.code == NSMigrationMissingMappingModelError)) {
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

- (BOOL)isInMemoryStore
{
    return !!_storeURL;
}

- (void)deleteStoreAndResetStack
{
    [[NSNotificationCenter defaultCenter] postNotificationName:AwfulDataStackWillResetNotification object:self];
    
    NSPersistentStoreCoordinator *persistentStoreCoordinator = _managedObjectContext.persistentStoreCoordinator;
    for (NSPersistentStore *store in persistentStoreCoordinator.persistentStores) {
        NSError *error;
        if (![persistentStoreCoordinator removePersistentStore:store error:&error]) {
            NSLog(@"%s error removing store at %@: %@", __PRETTY_FUNCTION__, store.URL, error);
        }
        
        if (_storeURL && ![store.URL isEqual:_storeURL]) {
            DeleteDataStoreAtURL(store.URL);
        }
    }
    if (_storeURL) {
        DeleteDataStoreAtURL(_storeURL);
    }
    
    [self addPersistentStore];
}

static NSArray * URLsForStoreURL(NSURL *storeURL)
{
    NSMutableArray *URLs = [NSMutableArray arrayWithObject:storeURL];
    for (NSString *detritusSuffix in @[ @"-shm", @"-wal" ]) {
        NSURLComponents *components = [NSURLComponents componentsWithURL:storeURL resolvingAgainstBaseURL:YES];
        components.path = [components.path stringByAppendingString:detritusSuffix];
        [URLs addObject:components.URL];
    }
    return URLs;
}

void DeleteDataStoreAtURL(NSURL *storeURL)
{
    NSArray *URLs = URLsForStoreURL(storeURL);
    for (NSURL *URL in URLs) {
        NSError *error;
        if (![[NSFileManager defaultManager] removeItemAtURL:URL error:&error]) {
            NSLog(@"%s error deleting part of SQLite store at %@: %@", __PRETTY_FUNCTION__, storeURL, error);
        }
    }
}

@end

BOOL MoveDataStore(NSURL *sourceURL, NSURL *destinationURL)
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *destinationFolder = [destinationURL URLByDeletingLastPathComponent];
    NSError *error;
    if (![fileManager createDirectoryAtURL:destinationFolder withIntermediateDirectories:YES attributes:nil error:&error]) {
        NSLog(@"%s error creating data store directory %@: %@", __PRETTY_FUNCTION__, destinationFolder, error);
        return NO;
    }
    
    __block BOOL success = YES;
    NSArray *sourceURLs = URLsForStoreURL(sourceURL);
    NSArray *destinationURLs = URLsForStoreURL(destinationURL);
    [sourceURLs enumerateObjectsUsingBlock:^(NSURL *sourceURL, NSUInteger i, BOOL *stop) {
        NSURL *destinationURL = destinationURLs[i];
        NSError *error;
        if (![fileManager moveItemAtURL:sourceURL toURL:destinationURL error:&error]) {
            if ([error.domain isEqualToString:NSCocoaErrorDomain]) {
                if (error.code == NSFileWriteFileExistsError || error.code == NSFileReadNoSuchFileError || error.code == NSFileNoSuchFileError) return;
            }
            NSLog(@"%s error moving part %@ of data store: %@", __PRETTY_FUNCTION__, sourceURL, error);
            success = NO;
        }
    }];
    return success;
}

NSString * const AwfulDataStackWillResetNotification = @"Awful data stack will reset";

@implementation NSManagedObjectContext (AwfulDataStack)

- (AwfulDataStack *)dataStack
{
    return objc_getAssociatedObject(self, DataStackKey);
}

@end
