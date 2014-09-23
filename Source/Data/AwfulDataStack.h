//  AwfulDataStack.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import CoreData;

/**
 * Creates a managed object context given the locations of the store and the model.
 */
@interface AwfulDataStack : NSObject

/**
 * Returns an initialized AwfulDataStack. This is one of two designated initializers.
 *
 * @param storeURL The location of the store. A new store is created in this location as needed (when there is no store, or when the existing store is incompatible with the model). If nil, an in-memory store is created and will not persist.
 * @param modelURL The location of the managed object model.
 */
- (id)initWithStoreURL:(NSURL *)storeURL modelURL:(NSURL *)modelURL;

/**
 * A managed object context operating on the main queue. Access its persistentStoreController property as needed.
 */
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

/**
 * Delete the store from disk and reset the data stack. All objects obtained from the stack's managedObjectContext are now invalid and should be forgotten under penalty of exception.
 */
- (void)deleteStoreAndResetStack;

@end

/**
 * Moves a data store from one place to another.
 *
 * @param sourceURL      The current location of the data store, including filename and extension.
 * @param destinationURL The desired location of the data store, including filename and extension.
 *
 * @return YES on success, or NO on failure.
 */
extern BOOL MoveDataStore(NSURL *sourceURL, NSURL *destinationURL);

/**
 * Deletes a data store.
 */
extern void DeleteDataStoreAtURL(NSURL *storeURL);

/**
 * Sent just before the data stack is deleted and reset. Any references to the data stack's managedObjectContext, including instances of NSManagedObject therefrom, should immediately be released (on penalty of exception upon next access).
 *
 * The notification's object is the data stack that will reset.
 */
extern NSString * const AwfulDataStackWillResetNotification;

@interface NSManagedObjectContext (AwfulDataStack)

/**
 * Returns the data stack that owns the managed object context.
 */
@property (readonly, weak, nonatomic) AwfulDataStack *dataStack;

@end
