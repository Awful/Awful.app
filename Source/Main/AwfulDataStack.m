//
//  AwfulDataStack.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulDataStack.h"
#import "AwfulErrorDomain.h"
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
    [self migrateFavorites];
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

- (void)migrateFavorites
{
    NSURL *url = [[self class] defaultStoreURL];
    NSError *error;
    NSURL *sourceModelURL = [self modelURLForStoreAtURL:url error:&error];
    NSAssert(sourceModelURL, @"could not find source model for %@: %@", url, error);
    NSString *sourceModelVersion = ModelNameWithURL(sourceModelURL);
    
    // If we're past the version that migrated favorites, we're done!
    NSComparisonResult doneUnlessAscending = [sourceModelVersion compare:@"Model-1.10.2-favorites"
                                                                 options:NSNumericSearch];
    if (doneUnlessAscending != NSOrderedAscending) return;
    
    // Otherwise, bring the store right up to the version before we migrated favorites.
    // This is almost certainly necessary, as Model-1.10.2 was not widely released.
    NSComparisonResult autoMigrateIfAscending = [sourceModelVersion compare:@"Model-1.10.2"
                                                                    options:NSNumericSearch];
    if (autoMigrateIfAscending == NSOrderedAscending) {
        NSManagedObjectModel *targetModel = [self modelWithName:@"Model-1.10.2"];
        NSPersistentStoreCoordinator *coordinator;
        coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:targetModel];
        NSDictionary *options = @{ NSMigratePersistentStoresAutomaticallyOption: @YES,
                                   NSInferMappingModelAutomaticallyOption: @YES };

        NSPersistentStore *store = [coordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                             configuration:nil
                                                                       URL:url
                                                                   options:options
                                                                     error:&error];
        NSAssert(store, @"failed automatic migration to 1.10.2: %@", error);
        BOOL ok = [coordinator removePersistentStore:store error:&error];
        NSAssert(ok, @"failed saving store migrated to 1.10.2: %@", error);
    }
    
    // At this point the store is at Model-1.10.2. Time to advance it to Model-1.10.2-favorites.
    NSManagedObjectModel *targetModel = [self modelWithName:@"Model-1.10.2-favorites"];
    BOOL ok = [self migrateStoreInPlaceAtURL:url toModel:targetModel error:&error];
    NSAssert(ok, @"failed to migrate store to 1.10.2-favorites: %@", error);
    
    // Any further migration can be done automatically by an interested persistent store
    // coordinator.
}

- (NSURL *)modelURLForStoreAtURL:(NSURL *)url error:(NSError **)error
{
    NSDictionary *metadata;
    metadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType
                                                                          URL:url error:error];
    if (!metadata) return nil;
    
    for (NSURL *url in [self bundledModelURLs]) {
        NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
        if ([model isConfiguration:nil compatibleWithStoreMetadata:metadata]) {
            *error = nil;
            return url;
        }
    }
    NSDictionary *userInfo = @{ NSLocalizedDescriptionKey: @"Data migration error",
                                NSLocalizedFailureReasonErrorKey: @"Could not locate model." };
    *error = [NSError errorWithDomain:AwfulErrorDomain code:AwfulErrorCodes.dataMigrationError
                             userInfo:userInfo];
    return nil;
}

- (NSArray *)bundledModelURLs
{
    NSMutableArray *modelURLs = [NSMutableArray new];
    NSArray *bundledMomdURLs = [[NSBundle mainBundle] URLsForResourcesWithExtension:@"momd"
                                                                       subdirectory:nil];
    for (NSURL *momd in bundledMomdURLs) {
        NSString *subdirectory = [momd lastPathComponent];
        NSArray *momURLs = [[NSBundle mainBundle] URLsForResourcesWithExtension:@"mom"
                                                                   subdirectory:subdirectory];
        [modelURLs addObjectsFromArray:momURLs];
    }
    return modelURLs;
}

- (NSManagedObjectModel *)modelWithName:(NSString *)modelName
{
    for (NSURL *url in [self bundledModelURLs]) {
        if ([ModelNameWithURL(url) isEqualToString:modelName]) {
            return [[NSManagedObjectModel alloc] initWithContentsOfURL:url];
        }
    }
    return nil;
}

static NSString * ModelNameWithURL(NSURL *url) {
    return [[url lastPathComponent] stringByDeletingPathExtension];
}

- (BOOL)migrateStoreInPlaceAtURL:(NSURL *)url
                         toModel:(NSManagedObjectModel *)destinationModel
                           error:(NSError **)error
{
    // None of the user info we're trying to migrate is terribly important. If this changes, this
    // method needs to be much more paranoid.
    NSDictionary *metadata;
    metadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType
                                                                          URL:url error:error];
    if (!metadata) {
        return NO;
    }
    
    // We need to determine the source model, so let's just try each one in turn.
    NSManagedObjectModel *sourceModel;
    for (NSURL *mom in [self bundledModelURLs]) {
        NSManagedObjectModel *model = [[NSManagedObjectModel alloc] initWithContentsOfURL:mom];
        if ([model isConfiguration:nil compatibleWithStoreMetadata:metadata]) {
            sourceModel = model;
            break;
        }
    }
    if (!sourceModel) {
        NSDictionary *userInfo = @{
            NSLocalizedDescriptionKey: @"Data migration error",
            NSLocalizedFailureReasonErrorKey: @"Could not locate source model."
        };
        *error = [NSError errorWithDomain:AwfulErrorDomain code:AwfulErrorCodes.dataMigrationError
                                 userInfo:userInfo];
        return NO;
    }
    
    NSMappingModel *mappingModel = [NSMappingModel mappingModelFromBundles:nil
                                                            forSourceModel:sourceModel
                                                          destinationModel:destinationModel];
    if (!mappingModel) {
        NSDictionary *userInfo = @{
            NSLocalizedDescriptionKey: @"Data migration error",
            NSLocalizedFailureReasonErrorKey: @"Missing mapping model."
        };
        *error = [NSError errorWithDomain:AwfulErrorDomain code:AwfulErrorCodes.dataMigrationError
                                 userInfo:userInfo];
        return NO;
    }
    
    NSMigrationManager *manager = [[NSMigrationManager alloc] initWithSourceModel:sourceModel
                                                                 destinationModel:destinationModel];
    NSString *filename = [[NSProcessInfo processInfo] globallyUniqueString];
    filename = [filename stringByAppendingPathExtension:[url pathExtension]];
    NSURL *destinationStoreURL = [url URLByDeletingLastPathComponent];
    destinationStoreURL = [destinationStoreURL URLByAppendingPathComponent:filename];
    BOOL ok = [manager migrateStoreFromURL:url
                                      type:NSSQLiteStoreType
                                   options:nil
                          withMappingModel:mappingModel
                          toDestinationURL:destinationStoreURL
                           destinationType:NSSQLiteStoreType
                        destinationOptions:nil error:error];
    if (!ok) {
        return NO;
    }
    NSFileManager *fileManager = [NSFileManager new];
    ok = [fileManager replaceItemAtURL:url
                         withItemAtURL:destinationStoreURL
                        backupItemName:nil
                               options:0
                      resultingItemURL:&url
                                 error:error];
    if (!ok) {
        return NO;
    }
    *error = nil;
    return YES;
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
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:AwfulDataStackDidResetNotification
                                                            object:self];
    });
}

+ (NSURL *)defaultStoreURL
{
    NSURL *caches = [[NSFileManager defaultManager] cachesDirectory];
    return [caches URLByAppendingPathComponent:@"AwfulData.sqlite"];
}

@end


NSString * const AwfulDataStackDidResetNotification = @"AwfulDataStackDidResetNotification";
