//
//  AwfulPageRefreshRequest.m
//  Awful
//
//  Created by Sean Berry on 11/13/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPageRefreshRequest.h"
#import "AwfulParse.h"
#import "AwfulPageCount.h"
#import "AwfulNavigator.h"
#import "AwfulConfig.h"
#import "AwfulForum.h"
#import "JSBridgeWebView.h"
#import "SALR.h"

@implementation AwfulPageRefreshRequest

@synthesize page = _page;

-(id)initWithAwfulPage : (AwfulPage *)page
{
    NSString *url_str = [@"http://forums.somethingawful.com/" stringByAppendingString:[page getURLSuffix]];
    
    if((self = [super initWithURL:[NSURL URLWithString:url_str]])) {
        _page = [page retain];
    }
    
    return self;
}

-(void)dealloc
{
    [_page release];
    [super dealloc];
}

-(void)requestFinished
{
    [super requestFinished];
    NSString *raw_s = [[NSString alloc] initWithData:[self responseData] encoding:NSASCIIStringEncoding];
    NSData *converted = [raw_s dataUsingEncoding:NSUTF8StringEncoding];
    
    TFHpple *page_data = [[TFHpple alloc] initWithHTMLData:converted];
    [raw_s release];
    
    if(self.page.thread.title == nil) {
        TFHppleElement *thread_title = [page_data searchForSingle:@"//a[@class='bclast']"];
        if(thread_title != nil) {
            [self.page setThreadTitle:[thread_title content]];
        }
    }
    
    if(self.page.thread.forum == nil) {
        NSArray *breadcrumbs = [page_data search:@"//div[@class='breadcrumbs']//a"];
        NSString *last_forum_id = nil;
        for(TFHppleElement *element in breadcrumbs) {
            NSString *src = [element objectForKey:@"href"];
            NSRange range = [src rangeOfString:@"forumdisplay.php"];
            if(range.location != NSNotFound) {
                NSArray *split = [src componentsSeparatedByString:@"="];
                last_forum_id = [split lastObject];
            }
        }
        if(last_forum_id != nil) {
            AwfulForum *forum = [AwfulForum awfulForumFromID:last_forum_id];
            self.page.thread.forum = forum;
        }
    }
    
    AwfulPageCount *pager = [AwfulParse newPageCount:page_data];
    [self.page setPages:pager];
    [pager release];
    
    BOOL fyad = [self.page.thread.forum.forumID isEqualToString:@"26"];
    NSMutableArray *parsed_posts = [AwfulParse newPostsFromThread:page_data isFYAD:fyad];
    [self.page acceptPosts:parsed_posts];
    
    int new_post_index = [AwfulParse getNewPostNumFromURL:[self url]] - 1;
    
    AwfulPost *newest_post = nil;
    
    if(new_post_index < [parsed_posts count] && new_post_index >= 0) {
        newest_post = [parsed_posts objectAtIndex:new_post_index];
        self.page.scrollToPostID = newest_post.postID;
    }
    
    int goal_posts_above = [AwfulConfig numReadPostsAbove];
    int remove_num_posts = 0;
    NSMutableArray *visible_posts = [NSMutableArray arrayWithArray:parsed_posts];
    
    if(newest_post != nil) {
        NSUInteger posts_above = [self.page.allRawPosts indexOfObject:newest_post];
       
        if(posts_above != NSNotFound) {
            remove_num_posts = MAX(0, posts_above - goal_posts_above);
            for(int i = 0; i < remove_num_posts; i++) {
                [visible_posts removeObjectAtIndex:0];
            }
        }
    }
    
    self.page.adHTML = [AwfulParse getAdHTMLFromData:page_data];
    
    int pages_left = self.page.pages.totalPages - self.page.pages.currentPage;
    NSString *html = [AwfulParse constructPageHTMLFromPosts:visible_posts pagesLeft:pages_left numOldPosts:remove_num_posts adHTML:self.page.adHTML];
        
    AwfulNavigator *nav = getNavigator();
    JSBridgeWebView *web = [[JSBridgeWebView alloc] initWithFrame:nav.view.frame];
    [self.page setWebView:web];
    [web loadHTMLString:html baseURL:[NSURL URLWithString:@"http://forums.somethingawful.com"]];
    
    [web release];

    [parsed_posts release];
    
    [page_data release];
}
    
@end
