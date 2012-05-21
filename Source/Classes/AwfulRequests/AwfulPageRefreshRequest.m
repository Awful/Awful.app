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
#import "AwfulPageDataController.h"

@implementation AwfulPageRefreshRequest

@synthesize page;

-(id)initWithAwfulPage : (AwfulPage *)aPage
{
    NSString *url_str = [@"http://forums.somethingawful.com/" stringByAppendingString:[aPage getURLSuffix]];
    
    if((self = [super initWithURL:[NSURL URLWithString:url_str]])) {
        self.page = aPage;
    }
    
    return self;
}


-(void)requestFinished
{
    [super requestFinished];
    
    AwfulPageDataController *data_controller = [[AwfulPageDataController alloc] initWithResponseData:[self responseData] pageURL:[self url]];
    self.page.dataController = data_controller;
    
    /*
    
    NSString *raw_s = [[NSString alloc] initWithData:[self responseData] encoding:NSASCIIStringEncoding];
    NSString *filtered_raw = [raw_s stringByReplacingOccurrencesOfString:@"<size:" withString:@"<"];
    NSData *converted = [filtered_raw dataUsingEncoding:NSUTF8StringEncoding];
    
    TFHpple *page_data = [[TFHpple alloc] initWithHTMLData:converted];
    
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
    
    BOOL fyad = [self.page.thread.forum.forumID isEqualToString:@"26"];
    NSMutableArray *parsed_posts = [AwfulParse newPostsFromThread:page_data isFYAD:fyad];
    [self.page acceptPosts:parsed_posts];
    
    int new_post_index = [AwfulParse getNewPostNumFromURL:[self url]] - 1;
    
    AwfulPost *newest_post = nil;
    
    if(new_post_index < [parsed_posts count] && new_post_index >= 0) {
        newest_post = [parsed_posts objectAtIndex:new_post_index];
        self.page.postIDScrollDestination = newest_post.postID;
    } else if(new_post_index == [parsed_posts count] && self.page.destinationType == AwfulPageDestinationTypeNewpost) {
        self.page.shouldScrollToBottom = YES;
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
    [web loadHTMLString:html baseURL:[NSURL URLWithString:@"http://forums.somethingawful.com"]];*/
}

-(void)failWithError:(NSError *)theError
{
    [super failWithError:theError];
    [self.page.navigator swapToRefreshButton];
}
    
@end
