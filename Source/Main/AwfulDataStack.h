//
//  AwfulDataStack.h
//  Awful
//
//  Created by Nolan Waite on 2012-10-10.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    AwfulDataStackInitFailureAbort,
    AwfulDataStackInitFailureDelete
} AwfulDataStackInitFailureAction;


@interface AwfulDataStack : NSObject

- (id)initWithStoreURL:(NSURL *)storeURL;

+ (AwfulDataStack *)sharedDataStack;

@property (readonly, strong, nonatomic) NSManagedObjectContext *context;
@property (readonly, nonatomic) NSManagedObjectContext *newContextForThread;

@property (readonly, strong, nonatomic) NSManagedObjectModel *model;

@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *coordinator;

@property (nonatomic) AwfulDataStackInitFailureAction initFailureAction;

- (void)save;

- (void)deleteAllDataAndResetStack;

+ (NSURL *)defaultStoreURL;

@end


// Sent after -deleteAllDataAndResetStack completes. The notification's object is the data stack.
// This might be a good time to recreate fetched results controllers or anything else that refers
// to a stack's managed object context.
extern NSString * const AwfulDataStackDidResetNotification;

// Sent after data is updated from iCloud.  FetchedResultsControllers, etc need to refresh themselves.  AwfulFetchedTableViewController listens for this, other things will need to themselves
extern NSString * const AwfulDataStackDidRemoteChangeNotification;
