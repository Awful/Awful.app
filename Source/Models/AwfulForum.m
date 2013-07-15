//
//  AwfulForum.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "AwfulForum.h"
#import "AwfulCategory.h"
#import "AwfulDataStack.h"
#import "AwfulThread.h"
#import "NSManagedObject+Awful.h"

@implementation AwfulForum

+ (instancetype)fetchOrInsertForumWithID:(NSString *)forumID
{
    AwfulForum *forum = [self firstMatchingPredicate:@"forumID = %@", forumID];
    if (!forum) {
        forum = [AwfulForum insertNew];
        forum.forumID = forumID;
        [[AwfulDataStack sharedDataStack] save];
    }
    return forum;
}

+ (NSArray *)updateCategoriesAndForums:(ForumHierarchyParsedInfo *)info
{
    NSMutableDictionary *existingForums = [NSMutableDictionary new];
    for (AwfulForum *f in [AwfulForum fetchAll]) {
        existingForums[f.forumID] = f;
    }
    NSMutableDictionary *existingCategories = [NSMutableDictionary new];
    for (AwfulCategory *c in [AwfulCategory fetchAll]) {
        existingCategories[c.categoryID] = c;
    }
    NSMutableArray *allForums = [NSMutableArray new];
    int indexOfCategory = 0;
    int indexOfForum = 0;
    for (CategoryParsedInfo *categoryInfo in info.categories) {
        AwfulCategory *category = existingCategories[categoryInfo.categoryID];
        if (!category) category = [AwfulCategory insertNew];
        category.categoryID = categoryInfo.categoryID;
        category.name = categoryInfo.name;
        category.indexValue = indexOfCategory++;
        NSMutableArray *forumStack = [categoryInfo.forums mutableCopy];
        while ([forumStack count] > 0) {
            ForumParsedInfo *forumInfo = [forumStack objectAtIndex:0];
            [forumStack removeObjectAtIndex:0];
            AwfulForum *forum = existingForums[forumInfo.forumID] ?: [AwfulForum insertNew];
            forum.forumID = forumInfo.forumID;
            forum.name = forumInfo.name;
            forum.category = category;
            forum.indexValue = indexOfForum++;
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
        [AwfulCategory deleteAllMatchingPredicate:@"NOT (categoryID IN %@)", keep];
    }
    
    if ([allForums count] > 0) {
        NSArray *keep = [allForums valueForKey:AwfulForumAttributes.forumID];
        [AwfulForum deleteAllMatchingPredicate:@"NOT (forumID IN %@)", keep];
    }
    
    [[AwfulDataStack sharedDataStack] save];
    return [allForums count] > 0 ? allForums : [existingForums allValues];
}

@end
