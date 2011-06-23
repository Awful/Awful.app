//
//  AwfulPageRefreshRequest.m
//  Awful
//
//  Created by Sean Berry on 11/13/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPageRefreshRequest.h"
#import "AwfulParse.h"
#import "AwfulNavController.h"
#import "AwfulPageCount.h"
#import "AwfulNavigator.h"

@implementation AwfulPageRefreshRequest

@synthesize page = _page;

-(id)initWithAwfulPage : (AwfulPage *)page
{
    _page = [page retain];
    
    NSString *url_str = [@"http://forums.somethingawful.com/" stringByAppendingString:[_page getURLSuffix]];
    self = [super initWithURL:[NSURL URLWithString:url_str]];
    
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
    
    self.page.newPostIndex = [AwfulParse getNewPostNumFromURL:[self url]];
    
    TFHpple *page_data = [[TFHpple alloc] initWithHTMLData:converted];
    [raw_s release];
    
    if(self.page.thread.title == nil) {
        TFHppleElement *thread_title = [page_data searchForSingle:@"//a[@class='bclast']"];
        if(thread_title != nil) {
            [self.page setThreadTitle:[thread_title content]];
        }
    }
    
    if(self.page.thread.forum.name == nil) {
        NSArray *breadcrumb_strings = [page_data rawSearch:@"//div[@class='breadcrumbs']"];
        if([breadcrumb_strings count] > 0) {
            NSString *bread = [breadcrumb_strings objectAtIndex:0];
            NSRange bread_range = [bread rangeOfString:@"FYAD"];
            if(bread_range.location != NSNotFound) {
                self.page.thread.forum.name = @"FYAD";
            }
        }
    }
    
    AwfulPageCount *pager = [AwfulParse newPageCount:page_data];
    [self.page setPages:pager];
    [pager release];
    
    BOOL fyad = [self.page.thread.forum.name isEqualToString:@"FYAD"];
    NSMutableArray *parsed_posts = [AwfulParse newPostsFromThread:page_data isFYAD:fyad];
    
    NSString *html = [AwfulParse constructPageHTMLFromPosts:parsed_posts];
    
    AwfulNavigator *nav = getNavigator();
    UIWebView *web = [[UIWebView alloc] initWithFrame:nav.view.frame];
    [web loadHTMLString:html baseURL:[NSURL URLWithString:@""]];
    self.page.webView = web;
    [web release];

    [self.page acceptPosts:parsed_posts];
    [parsed_posts release];
    
    [page_data release];
}

-(void)failWithError : (NSError *)err
{
    [self setError:err];
    AwfulNavController *nav = getnav();
    [nav requestFailed:self];

    [self.page stop];
}
    
@end
