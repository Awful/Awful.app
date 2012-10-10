//
//  AwfulForum+AwfulMethods.m
//  Awful
//
//  Created by Sean Berry on 3/28/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulForum+AwfulMethods.h"
#import "AwfulParsing.h"

@implementation AwfulForum (AwfulMethods)

+ (AwfulForum *)getForumWithID:(NSString *)forumID fromCurrentList:(NSArray *)currentList
{
    for (AwfulForum *existing in currentList) {
        if ([existing.forumID isEqualToString:forumID]) {
            return existing;
        }
    }
    AwfulForum *newForum = [AwfulForum insertNew];
    newForum.forumID = forumID;
    return newForum;
}

+ (NSArray *)updateCategoriesAndForums:(NSData *)data
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
    ForumHierarchyParsedInfo *info = [[ForumHierarchyParsedInfo alloc] initWithHTMLData:data];
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
            AwfulForum *forum = existingForums[forumInfo.forumID];
            if (!forum) {
                forum = [AwfulForum insertNew];
                forum.forumID = forumInfo.forumID;
            }
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

+ (NSString *)forumIDFromLinkElement:(TFHppleElement *)a
{
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"forumid=([0-9]*)" 
                                                                           options:NSRegularExpressionCaseInsensitive 
                                                                             error:nil];
    NSString *href = [a objectForKey:@"href"];
    NSRange range = [[regex firstMatchInString:href 
                                       options:0 
                                         range:NSMakeRange(0,href.length)] 
                     rangeAtIndex:1];
    return [href substringWithRange:range];
}

+ (void)updateSubforums:(NSArray *)rows inForum:(AwfulForum *)forum
{
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AwfulForum"];
    request.predicate = [NSPredicate predicateWithFormat:@"parentForum = %@", forum];
    NSError *error;
    NSArray *existingForums = [[AwfulDataStack sharedDataStack].context executeFetchRequest:request
                                                                                      error:&error];
    NSMutableDictionary *existingDict = [NSMutableDictionary new];
    for (AwfulForum* f in existingForums)
        [existingDict setObject:f forKey:f.forumID];

    for (NSString* row in rows) {
        TFHpple *rowBase = [[TFHpple alloc] initWithHTMLData:[row dataUsingEncoding:NSUTF8StringEncoding]];
        TFHppleElement* a = [rowBase searchForSingle:@"//td[" HAS_CLASS(title) "]//a"];
        AwfulForum *subforum = [existingDict objectForKey:[self forumIDFromLinkElement:a]];
        subforum.name = [a content];
        subforum.parentForum = forum;
        subforum.category = forum.category;
        subforum.forumID = [self forumIDFromLinkElement:a];
    }
}

@end
