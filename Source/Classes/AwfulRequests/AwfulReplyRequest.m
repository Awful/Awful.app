//
//  AwfulReplyRequest.m
//  Awful
//
//  Created by Sean Berry on 11/16/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulReplyRequest.h"
#import "AwfulThread.h"
#import "AwfulNavigator.h"
#import "AwfulPost.h"
#import "AwfulPage.h"
#import "AwfulPageCount.h"
#import "AwfulPostBoxController.h"
#import "TFHpple.h"
#import "NSString+HTML.h"
#import "AwfulAppDelegate.h"

@implementation CloserFormRequest

@synthesize thread, post;

-(void)requestFinished
{
    [super requestFinished];
    
    [AwfulPostBoxController clearStoredPost];
    
    UIViewController *vc = getRootController();
    [vc dismissModalViewControllerAnimated:YES];
    
    if(self.thread != nil) {
        AwfulPage *page = [AwfulPage pageWithAwfulThread:self.thread startAt:AwfulPageDestinationTypeNewpost];
        
        loadContentVC(page);
    } else if(self.post != nil) {
        AwfulNavigator *nav = getNavigator();
        if([nav.contentVC isMemberOfClass:[AwfulPage class]]) {
            AwfulPage *current_page = (AwfulPage *)nav.contentVC;
            AwfulPage *fresh_page = [AwfulPage pageWithAwfulThread:current_page.thread pageNum:current_page.pages.currentPage];
            fresh_page.postIDScrollDestination = self.post.postID;
            loadContentVC(fresh_page);
        }
    }
}

-(void)failWithError:(NSError *)theError
{
    [super failWithError:theError];
}

@end

@implementation AwfulReplyRequest

@synthesize reply, thread;

-(id)initWithReply : (NSString *)aReply forThread : (AwfulThread *)aThread
{
    NSString *url_str = [NSString stringWithFormat:@"http://forums.somethingawful.com/newreply.php?s=&action=newreply&threadid=%@", aThread.threadID];
    if((self = [super initWithURL:[NSURL URLWithString:url_str]])) {
        self.userInfo = [NSDictionary dictionaryWithObject:@"Posting..." forKey:@"loadingMsg"];
        self.reply = aReply;
        self.thread = aThread;
    }
    
    return self;
}

-(void)requestFinished
{
    [super requestFinished];
    
    NSString *raw_s = [[NSString alloc] initWithData:[self responseData] encoding:NSASCIIStringEncoding];
    NSData *converted = [raw_s dataUsingEncoding:NSUTF8StringEncoding];
    
    TFHpple *page_data = [[TFHpple alloc] initWithHTMLData:converted];
    
    CloserFormRequest *req = [CloserFormRequest requestWithURL:[NSURL URLWithString:@"http://forums.somethingawful.com/newreply.php"]];
    
    req.thread = self.thread;
    req.userInfo = [NSDictionary dictionaryWithObject:@"Posting..." forKey:@"loadingMsg"];
    
    TFHppleElement *formkey_element = [page_data searchForSingle:@"//input[@name='formkey']"];
    TFHppleElement *formcookie_element = [page_data searchForSingle:@"//input[@name='form_cookie']"];
    
    NSString *formkey = [formkey_element objectForKey:@"value"];
    NSString *formcookie = [formcookie_element objectForKey:@"value"];
    TFHppleElement *bookmark_element = [page_data searchForSingle:@"//input[@name='bookmark' and @checked='checked']"];
    if(bookmark_element != nil) {
        NSString *bookmark = [bookmark_element objectForKey:@"value"];
        [req addPostValue:bookmark forKey:@"bookmark"];
    }
    
    [req addPostValue:self.thread.threadID forKey:@"threadid"];
    [req addPostValue:formkey forKey:@"formkey"];
    [req addPostValue:formcookie forKey:@"form_cookie"];
    [req addPostValue:@"postreply" forKey:@"action"];
    [req addPostValue:[self.reply stringByEscapingUnicode] forKey:@"message"];
    [req addPostValue:@"yes" forKey:@"parseurl"];
    [req addPostValue:@"Submit Reply" forKey:@"submit"];
    
    loadRequestAndWait(req);
}

-(void)failWithError:(NSError *)theError
{
    [super failWithError:theError];
}

@end
