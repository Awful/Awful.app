//  SmilieDataStore.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import CoreData;

@interface SmilieDataStore : NSObject

// Main queue concurrency type.
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *storeCoordinator;

@property (readonly, strong, nonatomic) NSPersistentStore *bundledSmilieStore;

@property (readonly, strong, nonatomic) NSPersistentStore *appContainerSmilieStore;

+ (NSManagedObjectModel *)managedObjectModel;

@end

// NSPersistentStore metadata.
extern NSString * const SmilieMetadataVersionKey;
extern NSString * const SmilieLastSuccessfulScrapeDateKey;
