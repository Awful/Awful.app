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

//@property (nonatomic) NSURL *storeURL;

@end


@implementation AwfulDataStack

- (id)initWithStoreURL:(NSURL *)storeURL
{
    self = [super init];
    if (self) {
        //_storeURL = storeURL;
        [self context]; //initialize this here
    }
    return self;
}

- (id)init
{
    return [self initWithStoreURL:nil];
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
    if ([NSThread currentThread] != [NSThread mainThread]) {
        [NSException raise:@"YOU FUCKED UP"
                    format:@"Accessing main thread managedobjectcontext from a different thread."];
    }
    
    //NSLog(@"Main managed context");
    if (_context) return _context;
    
    _context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    //[_context performBlockAndWait:^{
        [_context setPersistentStoreCoordinator:self.coordinator];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(mergeChangesFrom_iCloud:)
                                                     name:NSPersistentStoreDidImportUbiquitousContentChangesNotification
                                                   object:self.coordinator
         ];
        
        //listen for changes on other threads
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(mergeChangesFromContextDidSaveNotification:)
                                                     name:NSManagedObjectContextDidSaveNotification
                                                   object:nil
         ];
    //}];

    return _context;
}

- (NSManagedObjectContext*) newContextForThread {
    //NSLog(@"new thread managed context");
    NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
    moc.persistentStoreCoordinator = self.coordinator;
    return moc;
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
    
    
    //[self loadiCloudStore];
    [self loadLocalStore];

    
    /*
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"SomethingChanged" object:self userInfo:nil];
        });
     */
    //});
            
    
    return _coordinator;
}

- (BOOL)loadiCloudStore {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSPersistentStoreCoordinator *psc = _coordinator;
        NSString *iCloudEnabledAppID = @"com.awfulapp.awful";
        NSString *dataFileName = @"AwfulData2.sqlite";
     
        NSString *iCloudDataDirectoryName = @"Data.nosync";
        NSFileManager *fileManager = [NSFileManager defaultManager];
        NSURL *iCloud = [fileManager URLForUbiquityContainerIdentifier:@"X2D4TQTBCQ.com.awfulapp.awful"];
        
        if (iCloud) {
            NSLog(@"iCloud is working");
            
            NSURL *iCloudLogsPath = [iCloud URLByAppendingPathComponent:@"Logs"];

            /*
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
             */
            
            NSURL *iCloudData = [[iCloud URLByAppendingPathComponent:iCloudDataDirectoryName]
                                    URLByAppendingPathComponent:dataFileName];
            
            NSDictionary *options = @{
                NSMigratePersistentStoresAutomaticallyOption: @YES,
                NSInferMappingModelAutomaticallyOption: @YES,
                NSPersistentStoreUbiquitousContentNameKey:iCloudEnabledAppID,
                NSPersistentStoreUbiquitousContentURLKey:iCloudLogsPath
            };
            [psc lock];
            
            NSError *error;
            [psc addPersistentStoreWithType:NSSQLiteStoreType
                              configuration:@"CloudConfig"
                                        URL:iCloudData
                                    options:options
                                      error:&error];
            NSLog(@"error=%@",error);
            [psc unlock];
            //return YES;
        }
        //return NO;
    });
    return NO;
}

- (BOOL)loadLocalStore {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSPersistentStoreCoordinator *psc = _coordinator;
        NSDictionary *options = @{
            NSMigratePersistentStoresAutomaticallyOption: @YES,
            NSInferMappingModelAutomaticallyOption:@YES
        };
        
        [psc lock];
        
        id store = [psc addPersistentStoreWithType:NSSQLiteStoreType
                                     configuration:nil
                                               URL:self.localStoreURL
                                           options:options
                                             error:nil
                    ];
        [psc unlock];
    });
    return NO;
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

- (NSURL *)localStoreURL
{
    NSURL *caches = [[NSFileManager defaultManager] cachesDirectory];
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

//handle updates from different threads
- (void) mergeChangesFromContextDidSaveNotification:(NSNotification*)notification
{
    if (notification.object != _context) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.context mergeChangesFromContextDidSaveNotification:notification];
            [self.context save:nil];
        });
    }
}

@end


NSString * const AwfulDataStackDidResetNotification = @"AwfulDataStackDidResetNotification";
NSString * const AwfulDataStackDidRemoteChangeNotification = @"AwfulDataStackDidRemoteChangeNotification";
