//
//  NSManagedObject+Awful.h
//  Awful
//
//  Created by Nolan Waite on 2012-10-10.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <CoreData/CoreData.h>

@interface NSManagedObject (Awful)

+ (NSArray *)fetchAll;
+ (NSArray*) fetchAllWithContext:(NSManagedObjectContext*)context;

+ (NSArray *)fetchAllMatchingPredicate:(id)formatOrPredicate, ...;
+ (NSArray *)fetchAllWithManagedObjectContext:(NSManagedObjectContext*)context matchingPredicate:(id)format, ...;

+ (instancetype)firstMatchingPredicate:(id)formatOrPredicate, ...;

+ (void)deleteAllMatchingPredicate:(NSString *)format, ...;

+ (instancetype)insertNew;

@end
