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

@synthesize thread = _thread;
@synthesize post = _post;


-(void)requestFinished
{
    [super requestFinished];
    
    [AwfulPostBoxController clearStoredPost];
    
    UIViewController *vc = getRootController();
    [vc dismissModalViewControllerAnimated:YES];
    
    if(self.thread != nil) {
        AwfulPage *page;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
            page = [[AwfulPage alloc] initWithAwfulThread:self.thread startAt:AwfulPageDestinationTypeNewpost];
        else
            page = [[AwfulPageIpad alloc] initWithAwfulThread:self.thread startAt:AwfulPageDestinationTypeNewpost];
        
        loadContentVC(page);
    } else if(self.post != nil) {
        AwfulNavigator *nav = getNavigator();
        if([nav.contentVC isMemberOfClass:[AwfulPage class]]) {
            AwfulPage *current_page = (AwfulPage *)nav.contentVC;
            AwfulPage *fresh_page;
            
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
                fresh_page = [[AwfulPage alloc] initWithAwfulThread:current_page.thread pageNum:current_page.pages.currentPage];
            else
                fresh_page = [[AwfulPageIpad alloc] initWithAwfulThread:current_page.thread pageNum:current_page.pages.currentPage];
            
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

@synthesize reply = _reply;
@synthesize thread = _thread;

-(id)initWithReply : (NSString *)reply forThread : (AwfulThread *)thread
{
    NSString *url_str = [NSString stringWithFormat:@"http://forums.somethingawful.com/newreply.php?s=&action=newreply&threadid=%@", thread.threadID];
    self = [super initWithURL:[NSURL URLWithString:url_str]];
    self.userInfo = [NSDictionary dictionaryWithObject:@"Posting..." forKey:@"loadingMsg"];

    _reply = reply;
    _thread = thread;
    
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
