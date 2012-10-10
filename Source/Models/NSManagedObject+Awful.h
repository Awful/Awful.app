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

+ (void)deleteAllMatchingPredicate:(NSString *)format, ...;

+ (id)insertNew;

@end
