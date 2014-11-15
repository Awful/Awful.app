//  AwfulManagedObject.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import CoreData;
@class AwfulObjectKey;

/**
 * An AwfulManagedObject is marginally more convenient than an NSManagedObject.
 */
@interface AwfulManagedObject : NSManagedObject

/**
 * Returns the name of the entity represented by the class. The default implementation returns the name of the class.
 */
+ (NSString *)entityName;

/**
 * Returns a new object of the class's entity inserted into a managed object context.
 */
+ (instancetype)insertInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 * Returns all objects of the class's entity that match a predicate.
 */
+ (NSArray *)fetchAllInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
                    matchingPredicateFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);

/**
 * Returns all objects of the class's entity that match a predicate.
 */
+ (NSArray *)fetchAllInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext matchingPredicate:(NSPredicate *)predicate;

/**
 Returns an array of objects of the class's entity matching the objectKeys.
 
 New objects are inserted as necessary, and only a single fetch is executed by the managedObjectContext. The returned array is sorted in the same order as objectKeys. Duplicate (or effectively duplicate) items in objectKeys is no problem and are maintained in the returned array.
 */
+ (NSArray *)objectsForKeys:(NSArray *)objectKeys inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

/**
 * Returns an arbitrary object of the class's entity that matches a predicate.
 */
+ (instancetype)fetchArbitraryInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
                             matchingPredicateFormat:(NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);

/**
 * Returns an arbitrary object of the class's entity that matches a predicate.
 */
+ (instancetype)fetchArbitraryInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext matchingPredicate:(NSPredicate *)predicate;

@end
