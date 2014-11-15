//  AwfulManagedObject.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulManagedObject.h"
#import "Awful-Swift.h"

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

#define NSPredicateWithFormatAndArguments(format) ({ \
    va_list args; \
    va_start(args, (format)); \
    NSPredicate *predicate = [NSPredicate predicateWithFormat:(format) arguments:args]; \
    va_end(args); \
    predicate; \
})

+ (NSArray *)fetchAllInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
                    matchingPredicateFormat:(NSString *)format, ...
{
    NSPredicate *predicate = NSPredicateWithFormatAndArguments(format);
    return [self fetchAllInManagedObjectContext:managedObjectContext matchingPredicate:predicate];
}

+ (NSArray *)fetchAllInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext matchingPredicate:(NSPredicate *)predicate
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:self.entityName];
    fetchRequest.predicate = predicate;
    NSError *error;
    NSArray *objects = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (!objects) {
        NSLog(@"%s error fetching %@ objects: %@", __PRETTY_FUNCTION__, self.entityName, error);
    }
    return objects;
}

+ (NSArray *)objectsForKeys:(NSArray *)objectKeys inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSParameterAssert(objectKeys.count > 1);
    NSParameterAssert(managedObjectContext);
    
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:self.entityName];
    NSMutableArray *subpredicates = [NSMutableArray new];
    NSDictionary *aggregateValues = [[objectKeys.firstObject class] valuesForKeysInObjectKeys:objectKeys];
    [aggregateValues enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSArray *values, BOOL *stop) {
        [subpredicates addObject:[NSPredicate predicateWithFormat:@"%K IN %@", key, values]];
    }];
    fetchRequest.predicate = [NSCompoundPredicate orPredicateWithSubpredicates:subpredicates];
    NSError *error;
    NSArray *existing = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (!existing) {
        @throw [NSException exceptionWithName:NSGenericException reason:@"fetch did fail" userInfo:@{NSUnderlyingErrorKey: error}];
    }
    NSMutableDictionary *existingByKey = [NSMutableDictionary dictionaryWithObjects:existing forKeys:[existing valueForKey:@"objectKey"]];
    
    NSMutableArray *objects = [NSMutableArray new];
    for (AwfulObjectKey *key in objectKeys) {
        AwfulManagedObject *object = existingByKey[key];
        if (!object) {
            object = [self insertInManagedObjectContext:managedObjectContext];
            [object applyObjectKey:key];
            existingByKey[key] = object;
        }
        [objects addObject:object];
    }
    return objects;
}

+ (instancetype)fetchArbitraryInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
                             matchingPredicateFormat:(NSString *)format, ...
{
    NSPredicate *predicate = NSPredicateWithFormatAndArguments(format);
    return [self fetchArbitraryInManagedObjectContext:managedObjectContext matchingPredicate:predicate];
}

+ (instancetype)fetchArbitraryInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext matchingPredicate:(NSPredicate *)predicate
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:self.entityName];
    fetchRequest.predicate = predicate;
    fetchRequest.fetchLimit = 1;
    NSError *error;
    NSArray *objects = [managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (!objects) {
        NSLog(@"%s error fetching arbitrary %@ object: %@", __PRETTY_FUNCTION__, self.entityName, error);
    }
    return objects.firstObject;
}

@end
