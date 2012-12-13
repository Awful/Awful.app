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

+ (NSArray *)fetchAllMatchingPredicate:(id)formatOrPredicate, ...;

+ (instancetype)firstMatchingPredicate:(id)formatOrPredicate, ...;

+ (void)deleteAllMatchingPredicate:(NSString *)format, ...;

+ (instancetype)insertNew;

@end
