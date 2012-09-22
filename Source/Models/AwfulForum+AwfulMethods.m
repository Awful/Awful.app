//
//  AwfulForum+AwfulMethods.m
//  Awful
//
//  Created by Sean Berry on 3/28/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulForum+AwfulMethods.h"
#import "TFHpple.h"
#import "TFHppleElement.h"
#import "XPathQuery.h"

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

+ (NSMutableArray *)parseForums:(NSData *)data
{
    NSManagedObjectContext *context = ApplicationDelegate.managedObjectContext;
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:[AwfulForum entityName]];
    NSError *error;
    NSArray *allExistingForums = [context executeFetchRequest:request error:&error];
    NSMutableDictionary *existingForums = [NSMutableDictionary new];
    for (AwfulForum *f in allExistingForums)
        existingForums[f.forumID] = f;
    request = [NSFetchRequest fetchRequestWithEntityName:[AwfulCategory entityName]];
    NSArray *allExistingCategories = [context executeFetchRequest:request error:&error];
    NSMutableDictionary *existingCategories = [NSMutableDictionary new];
    for (AwfulCategory *c in allExistingCategories)
        existingCategories[c.categoryID] = c;
    
    NSArray *rows = PerformRawHTMLXPathQuery(data, @"//tr");
    AwfulCategory *category;
    int indexOfCategory = 0;
    int i = 0;
    for (NSString* e in rows) {
        NSData *d = [e dataUsingEncoding:NSUTF8StringEncoding];
        TFHpple* kids = [[TFHpple alloc] initWithHTMLData:d];
        
        TFHppleElement* cat = [kids searchForSingle:@"//th[@class='category']//a"];
        if (cat) {
            NSString *categoryID = [self forumIDFromLinkElement:cat];
            category = existingCategories[categoryID];
            if (!category)
                category = [AwfulCategory insertInManagedObjectContext:context];
            category.categoryID = categoryID;
            category.name = [cat content];
            category.indexValue = indexOfCategory++;
        }
        
        TFHppleElement* img = [kids searchForSingle:@"//td[@class='icon']//img"];
        TFHppleElement* a = [kids searchForSingle:@"//td[@class='title']//a[@class='forum']"];
        
        if (img && a) { //forum
            AwfulForum *forum = existingForums[[self forumIDFromLinkElement:a]];
            if (!forum) forum = [AwfulForum insertInManagedObjectContext:context];
            forum.name = [a content];
            forum.desc = [a objectForKey:@"title"];
            forum.category = category;
            forum.forumID = [self forumIDFromLinkElement:a];
            forum.indexValue = i++;
            
            NSArray* subs = [kids search:@"//div[@class='subforums']//a"];
            for (TFHppleElement* s in subs) {
                AwfulForum *subforum = existingForums[[self forumIDFromLinkElement:s]];
                if (!subforum) subforum = [AwfulForum insertInManagedObjectContext:context];
                subforum.name = [s content];
                subforum.parentForum = forum;
                subforum.indexValue = i++;
                subforum.category = category;
                subforum.forumID = [self forumIDFromLinkElement:s];
            }
        }
    }
    
    [ApplicationDelegate saveContext];
    return nil;
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

+ (void)updateSubforums:(NSArray*)rows inForum:(AwfulForum*)forum
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
        TFHpple *row_base = [[TFHpple alloc] initWithHTMLData:[row dataUsingEncoding:NSUTF8StringEncoding]];

        TFHppleElement* a = [row_base searchForSingle:@"//td[@class='title']//a"];
        TFHppleElement* dd = [row_base searchForSingle:@"//td[@class='title']//dd"];
        
        AwfulForum *subforum = [existingDict objectForKey:[self forumIDFromLinkElement:a]];
        subforum.name = [a content];
        subforum.parentForum = forum;
        //subforum.indexValue = i++;
        subforum.category = forum.category;
        subforum.forumID = [self forumIDFromLinkElement:a];
        
        NSString *desc = [dd content];
        desc = [desc stringByReplacingOccurrencesOfString:@"- " withString:@""];
        subforum.desc = desc;
    }
}
@end
