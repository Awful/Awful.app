//  NSManagedObjectContext+AwfulConvenient.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import CoreData;

@interface NSManagedObjectContext (AwfulConvenient)

/**
 * -objectWithID: except nil-safe and returns `id` for easy casting.
 */
- (id)awful_objectWithID:(NSManagedObjectID *)objectID;

/**
 * -objectWithID: for each item in the array.
 *
 * @param objectIDs An array of NSManagedObjectID instances.
 */
- (NSArray *)awful_objectsWithIDs:(NSArray *)objectIDs;

@end
