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

@property (readonly, strong, nonatomic) NSManagedObjectModel *model;

@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *coordinator;

@property (nonatomic) AwfulDataStackInitFailureAction initFailureAction;

- (void)save;

- (void)deleteAllDataAndResetStack;

+ (NSURL *)defaultStoreURL;

@end
