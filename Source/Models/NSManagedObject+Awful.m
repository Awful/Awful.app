//
//  NSManagedObject+Awful.m
//  Awful
//
//  Created by Nolan Waite on 2012-10-10.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "NSManagedObject+Awful.h"

@implementation NSManagedObject (Awful)

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

+ (void)deleteAllMatchingPredicate:(NSString *)format, ...
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:[(Class)self entityName]];
    va_list args;
    va_start(args, format);
    request.predicate = [NSPredicate predicateWithFormat:format arguments:args];
    va_end(args);
    NSError *error;
    NSArray *dead = [[AwfulDataStack sharedDataStack].context executeFetchRequest:request
                                                                            error:&error];
    if (!dead) {
        NSLog(@"error deleting %@ matching %@: %@", self, request.predicate, error);
    }
    for (AwfulCategory *category in dead) {
        [category.managedObjectContext deleteObject:category];
    }
}

+ (id)insertNew
{
    return [(Class)self insertInManagedObjectContext:[AwfulDataStack sharedDataStack].context];
}

@end
