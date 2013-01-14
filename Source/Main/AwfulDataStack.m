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
    
    _context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [_context performBlockAndWait:^{
        [_context setPersistentStoreCoordinator:self.coordinator];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(mergeChangesFrom_iCloud:)
                                                     name:NSPersistentStoreDidImportUbiquitousContentChangesNotification
                                                   object:self.coordinator
         ];
    }];

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
    if((_coordinator != nil)) {
        return _coordinator;
    }
    
    _coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.model];
    NSPersistentStoreCoordinator *psc = _coordinator;
    
    // Set up iCloud in another thread:
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // ** Note: if you adapt this code for your own use, you MUST change this variable:
        NSString *iCloudEnabledAppID = @"X2D4TQTBCQ.com.awfulapp.awful";
        
        // ** Note: if you adapt this code for your own use, you should change this variable:
        NSString *dataFileName = @"AwfulData.sqlite";
        
        // ** Note: For basic usage you shouldn't need to change anything else
        
        NSString *iCloudDataDirectoryName = @"Data.nosync";
        NSString *iCloudLogsDirectoryName = @"Logs";
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *localStore = self.storeURL;
        NSURL *iCloud = [fileManager URLForUbiquityContainerIdentifier:nil];
        
        if (iCloud) {
            
            NSLog(@"iCloud is working");
            
            NSURL *iCloudLogsPath = [NSURL fileURLWithPath:[[iCloud path] stringByAppendingPathComponent:iCloudLogsDirectoryName]];
            
            NSLog(@"iCloudEnabledAppID = %@",iCloudEnabledAppID);
            NSLog(@"dataFileName = %@", dataFileName);
            NSLog(@"iCloudDataDirectoryName = %@", iCloudDataDirectoryName);
            NSLog(@"iCloudLogsDirectoryName = %@", iCloudLogsDirectoryName);
            NSLog(@"iCloud = %@", iCloud);
            NSLog(@"iCloudLogsPath = %@", iCloudLogsPath);
            
            if([fileManager fileExistsAtPath:[[iCloud path] stringByAppendingPathComponent:iCloudDataDirectoryName]] == NO) {
                NSError *fileSystemError;
                [fileManager createDirectoryAtPath:[[iCloud path] stringByAppendingPathComponent:iCloudDataDirectoryName]
                       withIntermediateDirectories:YES
                                        attributes:nil
                                             error:&fileSystemError];
                if(fileSystemError != nil) {
                    NSLog(@"Error creating database directory %@", fileSystemError);
                }
            }
            
            NSString *iCloudData = [[[iCloud path]
                                     stringByAppendingPathComponent:iCloudDataDirectoryName]
                                    stringByAppendingPathComponent:dataFileName];
            
            NSLog(@"iCloudData = %@", iCloudData);
            
            NSMutableDictionary *options = [NSMutableDictionary dictionary];
            [options setObject:[NSNumber numberWithBool:YES] forKey:NSMigratePersistentStoresAutomaticallyOption];
            [options setObject:[NSNumber numberWithBool:YES] forKey:NSInferMappingModelAutomaticallyOption];
            [options setObject:iCloudEnabledAppID            forKey:NSPersistentStoreUbiquitousContentNameKey];
            [options setObject:iCloudLogsPath                forKey:NSPersistentStoreUbiquitousContentURLKey];
            
            [psc lock];
            
            [psc addPersistentStoreWithType:NSSQLiteStoreType
                              configuration:nil
                                        URL:[NSURL fileURLWithPath:iCloudData]
                                    options:options
                                      error:nil];
            
            [psc unlock];
        }
        else {
            NSLog(@"iCloud is NOT working - using a local store");
            NSMutableDictionary *options = [NSMutableDictionary dictionary];
            [options setObject:[NSNumber numberWithBool:YES] forKey:NSMigratePersistentStoresAutomaticallyOption];
            [options setObject:[NSNumber numberWithBool:YES] forKey:NSInferMappingModelAutomaticallyOption];
            
            [psc lock];
            
            [psc addPersistentStoreWithType:NSSQLiteStoreType
                              configuration:nil
                                        URL:localStore
                                    options:options
                                      error:nil];
            [psc unlock];
            
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"SomethingChanged" object:self userInfo:nil];
        });
    });
    
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
    NSURL *caches = [[NSFileManager defaultManager] documentDirectory];
    return [caches URLByAppendingPathComponent:@"AwfulData.sqlite"];
}

- (void)mergeChangesFrom_iCloud:(NSNotification *)notification {
    
	NSLog(@"Merging in changes from iCloud...");
    [self.context performBlock:^{
        
        [self.context mergeChangesFromContextDidSaveNotification:notification];
        
        NSNotification* refreshNotification = [NSNotification notificationWithName:AwfulDataStackDidRemoteChangeNotification
                                                                            object:self
                                                                          userInfo:[notification userInfo]];
        
        [[NSNotificationCenter defaultCenter] postNotification:refreshNotification];
    }];
}

@end


NSString * const AwfulDataStackDidResetNotification = @"AwfulDataStackDidResetNotification";
NSString * const AwfulDataStackDidRemoteChangeNotification = @"AwfulDataStackDidRemoteChangeNotification";
