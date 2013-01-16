//
//  NSManagedObject+Awful.m
//  Awful
//
//  Created by Nolan Waite on 2012-10-10.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "NSManagedObject+Awful.h"
#import "AwfulDataStack.h"
#import "AwfulModels.h"

@implementation NSManagedObject (Awful)

/*
+ (void)fetchAllAndThen:(void (^)(NSError *error, NSArray *fetchedObjects, NSManagedObjectContext* threadContext))callback
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSManagedObjectContext *moc = [AwfulDataStack sharedDataStack].newThreadContext;
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:[(Class)self entityName]];
        NSError *error;
        NSArray *all = [moc executeFetchRequest:request error:&error];
        callback(error, all, moc);
    });
}

+(NSArray*) fetchAllWithContext:(NSManagedObjectContext*)context {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:[(Class)self entityName]];
    NSError *error;
    NSArray *all = [context executeFetchRequest:request
                                                                           error:&error];
    if (!all) {
        NSLog(@"error fetching all %@: %@", self, error);
    }
    return all;
}
*/
+ (NSArray *)fetchAll
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:[(Class)self entityName]];
    NSError *error;
    NSArray *all = [[AwfulDataStack sharedDataStack].context executeFetchRequest:request
                                                                           error:&error];
    if (!all) {
        NSLog(@"error fetching all %@: %@", self, error);
    }
    return all;
}
/*

+ (NSArray *)fetchAllWithManagedObjectContext:(NSManagedObjectContext*)context matchingPredicate:(id)format, ... {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:[(Class)self entityName]];
    if ([format isKindOfClass:[NSPredicate class]]) {
        [request setPredicate:(NSPredicate *)format];
    } else {
        va_list args;
        va_start(args, format);
        [request setPredicate:[NSPredicate predicateWithFormat:format arguments:args]];
        va_end(args);
    }
    NSError *error;
    NSArray *matches = [context executeFetchRequest:request
                                                                               error:&error];
    if (!matches) {
        NSLog(@"error fetching %@ matching %@: %@", self, [request predicate], error);
    }
    return matches;
}
*/

+ (NSArray *)fetchAllMatchingPredicate:(id)format, ...
{    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:[(Class)self entityName]];
    if ([format isKindOfClass:[NSPredicate class]]) {
        [request setPredicate:(NSPredicate *)format];
    } else {
        va_list args;
        va_start(args, format);
        [request setPredicate:[NSPredicate predicateWithFormat:format arguments:args]];
        va_end(args);
    }
    NSError *error;
    NSArray *matches = [[AwfulDataStack sharedDataStack].context executeFetchRequest:request
                                                                               error:&error];
    if (!matches) {
        NSLog(@"error fetching %@ matching %@: %@", self, [request predicate], error);
    }
    return matches;
}

+ (instancetype)firstMatchingPredicate:(id)formatOrPredicate, ...
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
    NSArray *matches = [[AwfulDataStack sharedDataStack].context executeFetchRequest:request
                                                                               error:&error];
    if (!matches) {
        NSLog(@"error fetching %@ matching %@: %@", self, [request predicate], error);
    }
    return [matches count] > 0 ? matches[0] : nil;
}

+ (void)deleteAllMatchingPredicate:(NSString *)format, ...
{
    va_list args;
    va_start(args, format);
    NSPredicate *predicate = [NSPredicate predicateWithFormat:format arguments:args];
    va_end(args);
    for (NSManagedObject *dying in [self fetchAllMatchingPredicate:predicate]) {
        [dying.managedObjectContext deleteObject:dying];
    }
}

+ (instancetype)insertNew
{
    return [(Class)self insertInManagedObjectContext:[AwfulDataStack sharedDataStack].context];
}

@end
