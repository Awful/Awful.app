//
//  AwfulReplyRequest.m
//  Awful
//
//  Created by Sean Berry on 11/16/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulReplyRequest.h"
#import "AwfulNavController.h"
#import "ASIFormDataRequest.h"
#import "NSString+HTML.h"

@implementation AwfulReplyRequest

-(id)initWithReply : (NSString *)in_reply forThread : (AwfulThread *)in_thread
{
    NSString *url_str = [NSString stringWithFormat:@"http://forums.somethingawful.com/newreply.php?s=&action=newreply&threadid=%@", in_thread.threadID];
    self = [super initWithURL:[NSURL URLWithString:url_str]];

    reply = [in_reply retain];
    thread = [in_thread retain];
    
    return self;
}

-(void)dealloc
{
    [reply release];
    [thread release];
    [super dealloc];
}

-(void)requestFinished
{
    NSString *raw_s = [[NSString alloc] initWithData:[self responseData] encoding:NSASCIIStringEncoding];
    NSData *converted = [raw_s dataUsingEncoding:NSUTF8StringEncoding];
    
    TFHpple *page_data = [[TFHpple alloc] initWithHTMLData:converted];
    [raw_s release];
    
    ASIFormDataRequest *req = [ASIFormDataRequest requestWithURL:[NSURL URLWithString:@"http://forums.somethingawful.com/newreply.php"]];
    
    TFHppleElement *formkey_element = [page_data searchForSingle:@"//input[@name='formkey']"];
    TFHppleElement *formcookie_element = [page_data searchForSingle:@"//input[@name='form_cookie']"];
    
    NSString *formkey = [formkey_element objectForKey:@"value"];
    NSString *formcookie = [formcookie_element objectForKey:@"value"];
    TFHppleElement *bookmark_element = [page_data searchForSingle:@"//input[@name='bookmark' and @checked='checked']"];
    if(bookmark_element != nil) {
        NSString *bookmark = [bookmark_element objectForKey:@"value"];
        [req addPostValue:bookmark forKey:@"bookmark"];
    }
    [page_data release];
    
    [req addPostValue:thread.threadID forKey:@"threadid"];
    [req addPostValue:formkey forKey:@"formkey"];
    [req addPostValue:formcookie forKey:@"form_cookie"];
    [req addPostValue:@"postreply" forKey:@"action"];
    [req addPostValue:[reply stringByEscapingUnicode] forKey:@"message"];
    [req addPostValue:@"yes" forKey:@"parseurl"];
    [req addPostValue:@"Submit Reply" forKey:@"submit"];
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:self.userInfo];
    [dict setObject:[NSNumber numberWithBool:YES] forKey:@"refresh"];
    
    req.userInfo = dict;
    
    AwfulNavController *nav = getnav();
    [nav loadRequestAndWait:req];
}

@end
