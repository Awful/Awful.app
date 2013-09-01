//
//  AwfulDataStack.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app
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


// Sent after receiving -deleteAllDataAndResetStack. The notification's object is the data stack.
// This is an opportune time to nil out any fetched results controllers.
extern NSString * const AwfulDataStackWillResetNotification;

// Sent after -deleteAllDataAndResetStack completes. The notification's object is the data stack.
// This is an opportune time to recreate any fetched results controllers.
extern NSString * const AwfulDataStackDidResetNotification;
