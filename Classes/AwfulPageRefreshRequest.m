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

@implementation AwfulPageRefreshRequest

@synthesize page;

-(id)initWithAwfulPage : (AwfulPage *)in_page
{
    page = [in_page retain];
    
    NSString *url_str = [@"http://forums.somethingawful.com/" stringByAppendingString:[page getURLSuffix]];
    self = [super initWithURL:[NSURL URLWithString:url_str]];
    
    return self;
}

-(void)dealloc
{
    [page release];
    [super dealloc];
}
    
-(void)requestFinished
{
    [super requestFinished];
    NSString *raw_s = [[NSString alloc] initWithData:[self responseData] encoding:NSASCIIStringEncoding];
    NSData *converted = [raw_s dataUsingEncoding:NSUTF8StringEncoding];
    
    page.newPostIndex = [AwfulParse getNewPostNumFromURL:[self url]];
    
    TFHpple *page_data = [[TFHpple alloc] initWithHTMLData:converted];
    [raw_s release];
    
    if(page.thread.title == nil) {
        TFHppleElement *thread_title = [page_data searchForSingle:@"//a[@class='bclast']"];
        if(thread_title != nil) {
            [page setThreadTitle:[thread_title content]];
        }
    }
    
    if(page.thread.forum.name == nil) {
        NSArray *breadcrumb_strings = [page_data rawSearch:@"//div[@class='breadcrumbs']"];
        if([breadcrumb_strings count] > 0) {
            NSString *bread = [breadcrumb_strings objectAtIndex:0];
            NSRange bread_range = [bread rangeOfString:@"FYAD"];
            if(bread_range.location != NSNotFound) {
                page.thread.forum.name = @"FYAD";
            }
        }
    }
    
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString *web_html = [AwfulParse getAdHTMLFromData:page_data];
    if(web_html != nil) {
        [page acceptAd:web_html];
    }
    [pool drain];
    
    AwfulPageCount *pager = [AwfulParse newPageCount:page_data];
    [page setPages:pager];
    [pager release];
    
    BOOL fyad = [page.thread.forum.name isEqualToString:@"FYAD"];
    NSMutableArray *parsed_posts = [AwfulParse newPostsFromThread:page_data isFYAD:fyad];

    [page acceptPosts:parsed_posts];
    [parsed_posts release];
    
    [page_data release];
}

-(void)failWithError : (NSError *)err
{
    [self setError:err];
    AwfulNavController *nav = getnav();
    [nav requestFailed:self];

    [page stop];
}
    
@end
