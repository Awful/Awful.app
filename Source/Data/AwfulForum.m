//  AwfulForum.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulForum.h"

@implementation AwfulForum

@dynamic forumID;
@dynamic index;
@dynamic lastRefresh;
@dynamic name;
@dynamic category;
@dynamic children;
@dynamic parentForum;
@dynamic threads;

+ (instancetype)fetchOrInsertForumInManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
                                                  withID:(NSString *)forumID
{
    AwfulForum *forum = [self fetchArbitraryInManagedObjectContext:managedObjectContext
                                           matchingPredicateFormat:@"forumID = %@", forumID];
    if (!forum) {
        forum = [AwfulForum insertInManagedObjectContext:managedObjectContext];
        forum.forumID = forumID;
    }
    return forum;
}

+ (NSArray *)updateCategoriesAndForums:(ForumHierarchyParsedInfo *)info
                inManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSMutableDictionary *existingForums = [NSMutableDictionary new];
    for (AwfulForum *f in [AwfulForum fetchAllInManagedObjectContext:managedObjectContext]) {
        existingForums[f.forumID] = f;
    }
    NSMutableDictionary *existingCategories = [NSMutableDictionary new];
    for (AwfulCategory *c in [AwfulCategory fetchAllInManagedObjectContext:managedObjectContext]) {
        existingCategories[c.categoryID] = c;
    }
    NSMutableArray *allForums = [NSMutableArray new];
    int32_t indexOfCategory = 0;
    int indexOfForum = 0;
    for (CategoryParsedInfo *categoryInfo in info.categories) {
        AwfulCategory *category = existingCategories[categoryInfo.categoryID];
        if (!category) category = [AwfulCategory insertInManagedObjectContext:managedObjectContext];
        category.categoryID = categoryInfo.categoryID;
        category.name = categoryInfo.name;
        category.index = indexOfCategory++;
        NSMutableArray *forumStack = [categoryInfo.forums mutableCopy];
        while ([forumStack count] > 0) {
            ForumParsedInfo *forumInfo = [forumStack objectAtIndex:0];
            [forumStack removeObjectAtIndex:0];
            AwfulForum *forum = (existingForums[forumInfo.forumID] ?:
                                 [AwfulForum insertInManagedObjectContext:managedObjectContext]);
            forum.forumID = forumInfo.forumID;
            forum.name = forumInfo.name;
            forum.category = category;
            forum.index = indexOfForum++;
            if (forumInfo.parentForum) {
                forum.parentForum = existingForums[forumInfo.parentForum.forumID];
            }
            [allForums addObject:forum];
            existingForums[forum.forumID] = forum;
            NSRange start = NSMakeRange(0, [forumInfo.subforums count]);
            [forumStack insertObjects:forumInfo.subforums
                            atIndexes:[NSIndexSet indexSetWithIndexesInRange:start]];
        }
    }
    
    if ([info.categories count] > 0) {
        NSArray *keep = [info.categories valueForKey:@"categoryID"];
        [AwfulCategory deleteAllInManagedObjectContext:managedObjectContext
                               matchingPredicateFormat:@"NOT (categoryID IN %@)", keep];
    }
    
    if ([allForums count] > 0) {
        NSArray *keep = [allForums valueForKey:@"forumID"];
        [AwfulForum deleteAllInManagedObjectContext:managedObjectContext
                            matchingPredicateFormat:@"NOT (forumID IN %@)", keep];
    }
    
    return [allForums count] > 0 ? allForums : [existingForums allValues];
}

@end
