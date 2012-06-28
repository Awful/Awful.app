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

-(id) init {
    self = [super initWithEntity:[NSEntityDescription entityForName:[[self class] description]
                                             inManagedObjectContext:ApplicationDelegate.managedObjectContext
                                  ]
  insertIntoManagedObjectContext:ApplicationDelegate.managedObjectContext];
    
    return self;
}

+(AwfulForum *)getForumWithID : (NSString *)forumID fromCurrentList : (NSArray *)currentList
{
    for(AwfulForum *existing in currentList) {
        if([existing.forumID isEqualToString:forumID]) {
            return existing;
        }
    }
    
    NSManagedObjectContext *moc = ApplicationDelegate.managedObjectContext;
    AwfulForum *newForum = [AwfulForum insertInManagedObjectContext:moc];
    newForum.forumID = forumID;
    return newForum;
}

+(NSMutableArray *)parseForums : (NSData *)data
{
    TFHpple *page_data = [[TFHpple alloc] initWithHTMLData:data];
    NSArray *forumLinks = PerformRawHTMLXPathQuery(page_data.data, @"//a[@class='forum']|//div[@class='subforums']//a");
    NSMutableArray *forumIDs = [NSMutableArray new];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"forumid=([0-9]*)" 
                                                                           options:NSRegularExpressionCaseInsensitive 
                                                                             error:nil];
    for (NSString* a in forumLinks) {
        TFHpple *link = [[TFHpple alloc] initWithHTMLData:[a dataUsingEncoding:NSUTF8StringEncoding]];
        TFHppleElement *aElement = [link searchForSingle:@"//a"];
        NSString *href = [aElement objectForKey:@"href"];
        NSRange range = [[regex firstMatchInString:href 
                                           options:0 
                                             range:NSMakeRange(0,href.length)] 
                         rangeAtIndex:1];
        NSString *idString = [href substringWithRange:range];
        
        if (idString != nil)
            [forumIDs addObject:[NSNumber numberWithInt:idString.intValue]];
    }
    
    NSArray *rows = PerformRawHTMLXPathQuery(data, @"//tr");
    
    int i = 0;
    AwfulForum* category;
    for (NSString* e in rows) {
        NSData *d = [e dataUsingEncoding:NSUTF8StringEncoding];
        TFHpple* kids = [[TFHpple alloc] initWithHTMLData:d];
        
 
        
        TFHppleElement* cat = [kids searchForSingle:@"//th[@class='category']//a"];
        if (cat) {
            category = [AwfulForum new];
            category.name = [cat content];
            category.forumID = [self forumIDFromLinkElement:cat];
            category.indexValue = i++;
            category.isCategoryValue = YES;
        }
        
        
        
        TFHppleElement* img = [kids searchForSingle:@"//td[@class='icon']//img"];
        TFHppleElement* a = [kids searchForSingle:@"//td[@class='title']//a[@class='forum']"];
        
        
        NSArray* subs = [kids search:@"//div[@class='subforums']//a"];
        
        if (img && a) { //forum
            AwfulForum *forum = [AwfulForum new];
            forum.name = [a content];
            forum.desc = [a objectForKey:@"title"];
            forum.category = category;
            
            NSString *href = [a objectForKey:@"href"];
            NSRange range = [[regex firstMatchInString:href 
                                               options:0 
                                                 range:NSMakeRange(0,href.length)] 
                             rangeAtIndex:1];
            NSString *idString = [href substringWithRange:range];
            
            
            forum.forumID = idString;
            forum.indexValue = i++;
            //forum.icon = [AwfulIcon new];
            //forum.icon.filename = [img objectForKey:@"src"];
            
            for (TFHppleElement* s in subs) {
                AwfulForum *subforum = [AwfulForum new];
                subforum.name = [s content];
                subforum.parentForum = forum;
                subforum.indexValue = i++;
                subforum.category = category;
                NSString *href = [s objectForKey:@"href"];
                NSRange range = [[regex firstMatchInString:href 
                                                   options:0 
                                                     range:NSMakeRange(0,href.length)] 
                                 rangeAtIndex:1];
                NSString *idString = [href substringWithRange:range];
                subforum.forumID = idString;
            }
            
            
        }
    }    
    [ApplicationDelegate saveContext];
/*
    NSArray *forum_elements = [page_data search:@"//select[@name='forumid']/option"];
    
    NSMutableArray *forums = [NSMutableArray array];
    NSMutableArray *parents = [NSMutableArray array];
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"AwfulForum" inManagedObjectContext:ApplicationDelegate.managedObjectContext]];
    
    NSError *error = nil;
    NSArray *existing_forums = [ApplicationDelegate.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    
    int last_dashes_count = 0;
    int index = 0;
    
    for(TFHppleElement *forum_element in forum_elements) {
        NSString *forum_id = [forum_element objectForKey:@"value"];
        NSString *forum_name = [forum_element content];
        
        if([forum_id intValue] > 0) {
            
            int num_dashes = 0;
            for(NSUInteger i=0; i < [forum_name length]; i++) {
                unichar c = [forum_name characterAtIndex:i];
                if(c == '-') {
                    num_dashes++;
                } else if(c == ' ') {
                    break;
                }
            }
            
            int substring_index = num_dashes;
            if(num_dashes > 0) {
                substring_index += 1; // space after last '-'
            }
            NSString *actual_forum_name = [forum_name substringFromIndex:substring_index];
            
            AwfulForum *forum = [AwfulForum getForumWithID:forum_id fromCurrentList:existing_forums];
            forum.name = actual_forum_name;
            forum.indexValue = index;
             
             if(num_dashes > last_dashes_count && [forums count] > 0) {
                 [parents addObject:[forums lastObject]];
             } else if(num_dashes < last_dashes_count) {
                 int diff = last_dashes_count - num_dashes;
                 for(int killer = 0; killer < diff / 2; killer++) {
                     [parents removeLastObject];
                 }
             }
             
             if([parents count] > 0) {
                 AwfulForum *parent = [parents lastObject];
                 forum.parentForum = parent;
             }
             
             last_dashes_count = num_dashes;
             
             [forums addObject:forum];
             index++;
        }
    }
    [ApplicationDelegate saveContext];
    return forums;
 */
    return nil;
}

+(NSString*) forumIDFromLinkElement:(TFHppleElement*)a {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"forumid=([0-9]*)" 
                                                                           options:NSRegularExpressionCaseInsensitive 
                                                                             error:nil];
    NSString *href = [a objectForKey:@"href"];
    NSRange range = [[regex firstMatchInString:href 
                                       options:0 
                                         range:NSMakeRange(0,href.length)] 
                     rangeAtIndex:1];
    return  [href substringWithRange:range];
}
@end
