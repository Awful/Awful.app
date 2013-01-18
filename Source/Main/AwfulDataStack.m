//
//  AwfulDataStack.m
//  Awful
//
//  Created by Nolan Waite on 2012-10-10.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulDataStack.h"
#import "NSFileManager+UserDirectories.h"

@interface AwfulDataStack ()

@property (strong, nonatomic) NSManagedObjectContext *context;
@property (strong, nonatomic) NSManagedObjectModel *model;
@property (strong, nonatomic) NSPersistentStoreCoordinator *coordinator;

@property (nonatomic) NSURL *storeURL;

@end


@implementation AwfulDataStack

- (id)initWithStoreURL:(NSURL *)storeURL
{
    self = [super init];
    if (self) {
        _storeURL = storeURL;
    }
    return self;
}

- (id)init
{
    return [self initWithStoreURL:[[self class] defaultStoreURL]];
}

+ (AwfulDataStack *)sharedDataStack
{
    static AwfulDataStack *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [self new];
    });
    return instance;
}

- (NSManagedObjectContext *)context
{
    if (_context) return _context;
    _context = [NSManagedObjectContext new];
    [_context setPersistentStoreCoordinator:self.coordinator];
    [_context setUndoManager:nil];
    return _context;
}

- (NSManagedObjectModel *)model
{
    if (_model) return _model;
    _model = [NSManagedObjectModel mergedModelFromBundles:nil];
    return _model;
}

- (NSPersistentStoreCoordinator *)coordinator
{
    if (_coordinator) return _coordinator;
    
    NSError *error;
    _coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.model];
    NSDictionary *options = @{
NSMigratePersistentStoresAutomaticallyOption: @YES,
NSInferMappingModelAutomaticallyOption: @YES
    };
    id ok = [_coordinator addPersistentStoreWithType:NSSQLiteStoreType
                                       configuration:nil
                                                 URL:self.storeURL
                                             options:options
                                               error:&error];
    if (!ok) {
        if (self.initFailureAction == AwfulDataStackInitFailureDelete) {
            [self deleteAllData];
            ok = [_coordinator addPersistentStoreWithType:NSSQLiteStoreType
                                            configuration:nil
                                                      URL:self.storeURL
                                                  options:options
                                                    error:&error];
            if (ok) return _coordinator;
        }
        NSLog(@"error loading persistent store at %@: %@", self.storeURL, error);
        abort();
    }
    return _coordinator;
}

- (void)deleteAllData
{
    NSArray *storeURLs = [[self.coordinator persistentStores] valueForKey:@"URL"];
    if ([storeURLs count] == 0) {
        storeURLs = @[ [[self class] defaultStoreURL] ];
    }
    for (NSPersistentStore *store in [self.coordinator persistentStores]) {
        NSError *error;
        BOOL ok = [self.coordinator removePersistentStore:store error:&error];
        if (!ok) {
            NSLog(@"failed to remove persistent store %@: %@", store, error);
        }
    }
    for (NSURL *storeURL in storeURLs) {
        NSError *error;
        BOOL ok = [[NSFileManager defaultManager] removeItemAtURL:storeURL error:&error];
        if (!ok) {
            NSLog(@"failed to delete data store %@: %@", storeURL, error);
        }
    }
}

- (void)save
{
    if (![self.context hasChanges]) return;
    NSError *error;
    BOOL ok = [self.context save:&error];
    if (!ok) {
        NSLog(@"failed saving managed object context %@: %@", self.context, error);
        abort();
    }
}

- (void)deleteAllDataAndResetStack
{
    [self deleteAllData];
    self.coordinator = nil;
    self.model = nil;
    self.context = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:AwfulDataStackDidResetNotification
                                                        object:self];
}

+ (NSURL *)defaultStoreURL
{
    NSURL *caches = [[NSFileManager defaultManager] cachesDirectory];
    return [caches URLByAppendingPathComponent:@"AwfulData.sqlite"];
}

@end


NSString * const AwfulDataStackDidResetNotification = @"AwfulDataStackDidResetNotification";
