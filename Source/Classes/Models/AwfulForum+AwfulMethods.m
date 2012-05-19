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

@implementation AwfulForum (AwfulMethods)

+(AwfulForum *)getForumWithID : (NSString *)forumID fromCurrentList : (NSArray *)currentList
{
    for(AwfulForum *existing in currentList) {
        if([existing.forumID isEqualToString:forumID]) {
            return existing;
        }
    }
    
    AwfulForum *newForum = [NSEntityDescription insertNewObjectForEntityForName:@"AwfulForum" inManagedObjectContext:ApplicationDelegate.managedObjectContext];
    [newForum setForumID:forumID];
    return newForum;
}

+(NSMutableArray *)parseForums : (NSData *)data
{
    TFHpple *page_data = [[TFHpple alloc] initWithHTMLData:data];
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
                                 
            [forum setName:actual_forum_name];
            [forum setIndex:[NSNumber numberWithInt:index]];
             
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
                 [forum setParentForum:parent];
                 //[forum setParentForum:parent];
             }
             
             last_dashes_count = num_dashes;
             
             [forums addObject:forum];
             index++;
        }
    }
    [ApplicationDelegate saveContext];
    return forums;
}

@end
