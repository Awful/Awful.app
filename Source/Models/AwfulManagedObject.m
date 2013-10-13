//  AwfulManagedObject.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulManagedObject.h"

@implementation AwfulManagedObject

+ (NSString *)entityName
{
    return NSStringFromClass(self);
}

+ (instancetype)insertInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    return [NSEntityDescription insertNewObjectForEntityForName:self.entityName
                                         inManagedObjectContext:managedObjectContext];
}

+ (NSArray *)fetchAllInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:self.entityName];
    NSError *error;
    NSArray *objects = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (!objects) {
        NSLog(@"%s error fetching all %@ objects: %@", __PRETTY_FUNCTION__, self.entityName, error);
    }
    return objects;
}

#define NSPredicateWithFormatAndArguments(format) ({ \
    va_list __args; \
    va_start(__args, (format)); \
    NSPredicate *__predicate = [NSPredicate predicateWithFormat:(format) arguments:__args]; \
    va_end(__args); \
    __predicate; \
})

+ (NSArray *)fetchAllInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
                    matchingPredicateFormat:(NSString *)format, ...
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:self.entityName];
    fetchRequest.predicate = NSPredicateWithFormatAndArguments(format);
    NSError *error;
    NSArray *objects = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (!objects) {
        NSLog(@"%s error fetching %@ objects: %@", __PRETTY_FUNCTION__, self.entityName, error);
    }
    return objects;
}

+ (BOOL)anyInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
          matchingPredicateFormat:(NSString *)format, ...
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:self.entityName];
    fetchRequest.predicate = NSPredicateWithFormatAndArguments(format);
    NSError *error;
    NSUInteger count = [managedObjectContext countForFetchRequest:fetchRequest error:&error];
    if (count == NSNotFound) {
        NSLog(@"%s error counting %@ objects: %@", __PRETTY_FUNCTION__, self.entityName, error);
    }
    return count != 0;
}

+ (instancetype)fetchArbitraryInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
                             matchingPredicateFormat:(NSString *)format, ...
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:self.entityName];
    fetchRequest.predicate = NSPredicateWithFormatAndArguments(format);
    fetchRequest.fetchLimit = 1;
    NSError *error;
    NSArray *objects = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (!objects) {
        NSLog(@"%s error fetching arbitrary %@ object: %@", __PRETTY_FUNCTION__, self.entityName, error);
    }
    return objects.firstObject;
}

+ (BOOL)deleteAllInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
                matchingPredicateFormat:(NSString *)format, ...
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:self.entityName];
    fetchRequest.predicate = NSPredicateWithFormatAndArguments(format);
    NSError *error;
    NSArray *objects = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (!objects) {
        NSLog(@"%s error deleting %@ objects: %@", __PRETTY_FUNCTION__, self.entityName, error);
        return NO;
    }
    for (AwfulManagedObject *object in objects) {
        [managedObjectContext deleteObject:object];
    }
    return YES;
}

@end
