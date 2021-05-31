//  SmilieManagedObject.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "SmilieManagedObject.h"

@implementation SmilieManagedObject

+ (NSString *)entityName
{
    return NSStringFromClass(self);
}

+ (instancetype)newInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    return [NSEntityDescription insertNewObjectForEntityForName:[self entityName] inManagedObjectContext:managedObjectContext];
}

@end
