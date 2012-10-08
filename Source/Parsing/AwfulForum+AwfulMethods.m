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
    
    NSManagedObjectContext *moc = ApplicationDelegate.managedObjectContext;
    AwfulForum *newForum = [AwfulForum insertInManagedObjectContext:moc];
    newForum.forumID = forumID;
    return newForum;
}

+ (NSArray *)parseForums:(NSData *)data
{
    NSManagedObjectContext *context = ApplicationDelegate.managedObjectContext;
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:[AwfulForum entityName]];
    NSError *error;
    NSArray *allExistingForums = [context executeFetchRequest:request error:&error];
    NSMutableDictionary *existingForums = [NSMutableDictionary new];
    for (AwfulForum *f in allExistingForums) {
        existingForums[f.forumID] = f;
    }
    request = [NSFetchRequest fetchRequestWithEntityName:[AwfulCategory entityName]];
    NSArray *allExistingCategories = [context executeFetchRequest:request error:&error];
    NSMutableDictionary *existingCategories = [NSMutableDictionary new];
    for (AwfulCategory *c in allExistingCategories) {
        existingCategories[c.categoryID] = c;
    }
    
    // There's a pulldown menu at the bottom of forumdisplay.php and showthread.php like this:
    //
    // <select name="forumid">
    //   <option value="-1">Whatever</option>
    //   <option value="pm">Private Messages</option>
    //   ...
    //   <option value="-1">--------------------</option>
    //   <option value="48"> Main</option>
    //   <option value="1">-- General Bullshit</option>
    //   <option value="155">---- SA's Front Page Discussion</option>
    //   ...
    // </select>
    //
    // This is the only place that lists *all* forums. index.php only shows one level of subforums.
    TFHpple *forumdisplay = [[TFHpple alloc] initWithHTMLData:data];
    NSArray *listOfItems = [forumdisplay search:@"//select[@name='forumid']/option"];
    int indexOfCategory = 0;
    int indexOfForum = 0;
    
    NSMutableArray *allCategories = [NSMutableArray new];
    NSMutableArray *allForums = [NSMutableArray new];
    AwfulCategory *category;
    NSMutableArray *forumStack = [NSMutableArray new];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"^(-*) ?(.*)$"
                                                                           options:0
                                                                             error:&error];
    if (!regex) {
        NSLog(@"Regex failure parsing forums: %@", error);
        return nil;
    }
    
    for (TFHppleElement *item in listOfItems) {
        NSString *forumOrCategoryID = [item objectForKey:@"value"];
        if ([forumOrCategoryID integerValue] <= 0)
            continue;
        
        NSTextCheckingResult *match = [regex firstMatchInString:[item content]
                                                        options:0
                                                          range:NSMakeRange(0, [[item content] length])];
        NSString *name = [[item content] substringWithRange:[match rangeAtIndex:2]];
        NSUInteger depth = [match rangeAtIndex:1].length / 2;
        if (depth == 0) {
            [forumStack removeAllObjects];
            category = existingCategories[forumOrCategoryID];
            if (!category)
                category = [AwfulCategory insertInManagedObjectContext:context];
            category.categoryID = forumOrCategoryID;
            category.name = name;
            category.indexValue = indexOfCategory++;
            [allCategories addObject:category];
        } else {
            while ([forumStack count] >= depth) {
                [forumStack removeLastObject];
            }
            AwfulForum *forum = existingForums[forumOrCategoryID];
            if (!forum) forum = [AwfulForum insertInManagedObjectContext:context];
            forum.name = name;
            forum.category = category;
            forum.forumID = forumOrCategoryID;
            forum.indexValue = indexOfForum++;
            if ([forumStack count])
                forum.parentForum = [forumStack lastObject];
            [forumStack addObject:forum];
            [allForums addObject:forum];
            existingForums[forum.forumID] = forum;
        }
    }
    
    // Remove categories we didn't come across.
    if ([allCategories count] > 0) {
        request = [NSFetchRequest fetchRequestWithEntityName:[AwfulCategory entityName]];
        NSArray *keep = [allCategories valueForKey:AwfulCategoryAttributes.categoryID];
        request.predicate = [NSPredicate predicateWithFormat:@"NOT (categoryID IN %@)", keep];
        NSArray *dead = [ApplicationDelegate.managedObjectContext executeFetchRequest:request
                                                                                error:&error];
        if (!dead) {
            NSLog(@"Error deleting dead categories: %@", error);
            return nil;
        }
        for (AwfulCategory *category in dead)
            [category.managedObjectContext deleteObject:category];
    }
    
    // Ditto for forums.
    if ([allForums count] > 0) {
        request = [NSFetchRequest fetchRequestWithEntityName:[AwfulForum entityName]];
        NSArray *keep = [allForums valueForKey:AwfulForumAttributes.forumID];
        request.predicate = [NSPredicate predicateWithFormat:@"NOT (forumID IN %@)", keep];
        NSArray *dead = [ApplicationDelegate.managedObjectContext executeFetchRequest:request
                                                                                error:&error];
        if (!dead) {
            NSLog(@"Error deleting dead forums: %@", error);
            return nil;
        }
        for (AwfulForum *forum in dead)
            [forum.managedObjectContext deleteObject:forum];
    }
    
    [ApplicationDelegate saveContext];
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
    NSArray *existingForums = [ApplicationDelegate.managedObjectContext executeFetchRequest:request
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
