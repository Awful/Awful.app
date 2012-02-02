//
//  AwfulForumListRefreshRequest.m
//  Awful
//
//  Created by Regular Berry on 6/14/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulForumListRefreshRequest.h"
#import "TFHpple.h"
#import "AwfulForum.h"
#import "AwfulForumsList.h"

@implementation AwfulForumListRefreshRequest

@synthesize forumsList = _forumsList;

-(id)initWithForumsList : (AwfulForumsList *)list
{
    // grabs forum list from the dropdown at the bottom of a forumdisplay page
    self = [super initWithURL:[NSURL URLWithString:@"http://forums.somethingawful.com/forumdisplay.php?forumid=1"]];
    self.userInfo = [NSDictionary dictionaryWithObject:@"Got forums..." forKey:@"completionMsg"];
    _forumsList = list;
    
    return self;
}


-(void)requestFinished
{
    [super requestFinished];
    TFHpple *page_data = [[TFHpple alloc] initWithHTMLData:[self responseData]];
    NSArray *forum_elements = [page_data search:@"//select[@name='forumid']/option"];
    
    NSMutableArray *forums = [NSMutableArray array];
    NSMutableArray *parents = [NSMutableArray array];
    
    int last_dashes_count = 0;
    
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
            
            AwfulForum *forum = [[AwfulForum alloc] init];
            [forum setName:actual_forum_name];
            [forum setForumID:forum_id];
            
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
                [forum setParentForumID:parent.forumID];
            }
            
            last_dashes_count = num_dashes;
            
            [forums addObject:forum];
        }
    }
    [self.forumsList setForums:forums];
}

@end
