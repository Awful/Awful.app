//  SmilieDataStore.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import CoreData;

@interface SmilieDataStore : NSObject

/**
 A managed object context connected to both persistent stores, set to main queue concurrency type.
 */
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *storeCoordinator;

/**
 The persistent store shipped as part of the Smilies.framework bundle. Read-only.
 */
@property (readonly, strong, nonatomic) NSPersistentStore *bundledSmilieStore;

/**
 The persistent store that's actually editable.
 */
@property (readonly, strong, nonatomic) NSPersistentStore *appContainerSmilieStore;

+ (NSManagedObjectModel *)managedObjectModel;

@end

/**
 An integer set in the bundled smilie store's metadata, incremented whenever the bundled smilies change; or an integer set in the app container smilie store's metadata, used to delete downloaded smilies that were subsequently bundled.
 */
extern NSString * const SmilieMetadataVersionKey;

/**
 An NSDate set in the app container smilie store's metadata, indicating the last time a scrape finished successfully.
 */
extern NSString * const SmilieLastSuccessfulScrapeDateKey;
