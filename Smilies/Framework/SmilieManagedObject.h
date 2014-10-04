//  SmilieManagedObject.h
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import CoreData;

@interface SmilieManagedObject : NSManagedObject

+ (NSString *)entityName;

+ (instancetype)newInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext;

@end
