//
//  AwfulQuoteRequest.m
//  Awful
//
//  Created by Sean Berry on 11/17/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulQuoteRequest.h"
#import "AwfulPage.h"
#import "AwfulPost.h"
#import "AwfulAppDelegate.h"

@implementation AwfulQuoteRequest

@synthesize page = _page;

-(id)initWithPost : (AwfulPost *)post fromPage : (AwfulPage *)page
{
    _page = page;
    
    NSString *url_str = [NSString stringWithFormat:@"http://forums.somethingawful.com/newreply.php?action=newreply&postid=%@", post.postID];
    
    self = [super initWithURL:[NSURL URLWithString:url_str]];
    
    return self;
}


-(void)requestFinished
{
    [super requestFinished];
    NSString *raw_s = [[NSString alloc] initWithData:[self responseData] encoding:NSASCIIStringEncoding];
    NSData *converted = [raw_s dataUsingEncoding:NSUTF8StringEncoding];

    TFHpple *base = [[TFHpple alloc] initWithHTMLData:converted];
    TFHppleElement *quote_el = [base searchForSingle:@"//textarea[@name='message']"];
    
    [AwfulPostBoxController clearStoredPost];
    AwfulPostBoxController *post_box = [[AwfulPostBoxController alloc] initWithText:[NSString stringWithFormat:@"%@\n", [quote_el content]]];
    [post_box setThread:self.page.thread];
    
    UIViewController *vc = getRootController();
    [vc presentModalViewController:post_box animated:YES];

}

@end
