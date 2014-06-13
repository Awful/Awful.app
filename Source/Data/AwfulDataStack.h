//  AwfulDataStack.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <CoreData/CoreData.h>

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
 * Moves a data store from one place to another. Throws an exception if the move fails for any reason other than when no file exists at the source URL.
 *
 * @param sourceURL      The current location of the data store, including filename and extension.
 * @param destinationURL The desired location of the data store, including filename and extension.
 */
extern void MoveDataStore(NSURL *sourceURL, NSURL *destinationURL);
