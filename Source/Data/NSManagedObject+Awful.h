//  NSManagedObject+Awful.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <CoreData/CoreData.h>

@interface NSManagedObject (Awful)

+ (NSArray *)fetchAllInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

+ (NSArray *)fetchAllInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
                          matchingPredicate:(id)formatOrPredicate, ...;

+ (instancetype)firstInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
                          matchingPredicate:(id)formatOrPredicate, ...;

+ (void)deleteAllInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
                      matchingPredicate:(NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);

@end
