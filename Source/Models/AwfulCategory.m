//  AwfulCategory.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulCategory.h"

@implementation AwfulCategory

@dynamic categoryID;
@dynamic index;
@dynamic name;
@dynamic forums;

+ (instancetype)firstOrNewCategoryWithCategoryID:(NSString *)categoryID
                          inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSParameterAssert(categoryID.length > 0);
    AwfulCategory *category = [self fetchArbitraryInManagedObjectContext:managedObjectContext
                                                 matchingPredicateFormat:@"categoryID = %@", categoryID];
    if (!category) {
        category = [self insertInManagedObjectContext:managedObjectContext];
        category.categoryID = categoryID;
    }
    return category;
}

@end
