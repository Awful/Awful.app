//  NSManagedObject+Awful.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "NSManagedObject+Awful.h"
#import "AwfulModels.h"

@implementation NSManagedObject (Awful)

+ (NSArray *)fetchAllInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:[(Class)self entityName]];
    NSError *error;
    NSArray *all = [managedObjectContext executeFetchRequest:request error:&error];
    if (!all) {
        NSLog(@"error fetching all %@: %@", self, error);
    }
    return all;
}

+ (NSArray *)fetchAllInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
                          matchingPredicate:(id)formatOrPredicate, ...
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:[(Class)self entityName]];
    if ([formatOrPredicate isKindOfClass:[NSPredicate class]]) {
        [request setPredicate:(NSPredicate *)formatOrPredicate];
    } else {
        va_list args;
        va_start(args, formatOrPredicate);
        [request setPredicate:[NSPredicate predicateWithFormat:formatOrPredicate arguments:args]];
        va_end(args);
    }
    NSError *error;
    NSArray *matches = [managedObjectContext executeFetchRequest:request error:&error];
    if (!matches) {
        NSLog(@"error fetching %@ matching %@: %@", self, [request predicate], error);
    }
    return matches;
}

+ (instancetype)firstInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
                          matchingPredicate:(id)formatOrPredicate, ...
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:[(Class)self entityName]];
    if ([formatOrPredicate isKindOfClass:[NSPredicate class]]) {
        [request setPredicate:(NSPredicate *)formatOrPredicate];
    } else {
        va_list args;
        va_start(args, formatOrPredicate);
        [request setPredicate:[NSPredicate predicateWithFormat:formatOrPredicate arguments:args]];
        va_end(args);
    }
    NSError *error;
    NSArray *matches = [managedObjectContext executeFetchRequest:request error:&error];
    if (!matches) {
        NSLog(@"error fetching %@ matching %@: %@", self, [request predicate], error);
    }
    return [matches count] > 0 ? matches[0] : nil;
}

+ (void)deleteAllInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
                      matchingPredicate:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSPredicate *predicate = [NSPredicate predicateWithFormat:format arguments:args];
    va_end(args);
    for (NSManagedObject *dying in [self fetchAllInManagedObjectContext:managedObjectContext
                                                      matchingPredicate:predicate]) {
        [managedObjectContext deleteObject:dying];
    }
}

@end
