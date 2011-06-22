//
//  AwfulQuoteRequest.m
//  Awful
//
//  Created by Sean Berry on 11/17/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulQuoteRequest.h"
#import "AwfulNavController.h"

@implementation AwfulQuoteRequest

-(id)initWithPost : (AwfulPost *)post fromPage : (AwfulPage *)in_page
{
    page = [in_page retain];
    
    NSString *url_str = [NSString stringWithFormat:@"http://forums.somethingawful.com/newreply.php?action=newreply&postid=%@", post.postID];
    
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
    [raw_s release];

    TFHpple *base = [[TFHpple alloc] initWithHTMLData:converted];
    TFHppleElement *quote_el = [base searchForSingle:@"//textarea[@name='message']"];
    
    AwfulPostBoxController *post_box = [[AwfulPostBoxController alloc] initWithText:[NSString stringWithFormat:@"%@\n", [quote_el content]]];
    [post_box setReplyBox:page.thread];
    
    AwfulNavController *nav = getnav();
    [nav presentModalViewController:post_box animated:YES];
    [post_box release];

    [base release];
}

@end
