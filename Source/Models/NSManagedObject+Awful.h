//
//  NSManagedObject+Awful.h
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import <CoreData/CoreData.h>

@interface NSManagedObject (Awful)

+ (NSArray *)fetchAll;

+ (NSArray *)fetchAllMatchingPredicate:(id)formatOrPredicate, ...;

+ (instancetype)firstMatchingPredicate:(id)formatOrPredicate, ...;

+ (void)deleteAllMatchingPredicate:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);

+ (instancetype)insertNew;

@end
