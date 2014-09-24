//  NSManagedObjectContext+AwfulConvenient.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "NSManagedObjectContext+AwfulConvenient.h"

@implementation NSManagedObjectContext (AwfulConvenient)

- (id)awful_objectWithID:(NSManagedObjectID *)objectID
{
    if (!objectID) return nil;
    return (id)[self objectWithID:objectID];
}

- (NSArray *)awful_objectsWithIDs:(NSArray *)objectIDs
{
    NSMutableArray *objects = [NSMutableArray new];
    for (NSManagedObjectID *objectID in objectIDs) {
        NSManagedObject *object = [self objectWithID:objectID];
        [objects addObject:object];
    }
    return objects;
}

@end
