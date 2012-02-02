//
//  AwfulEditRequest.m
//  Awful
//
//  Created by Sean Berry on 11/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulEditRequest.h"
#import "AwfulPostBoxController.h"
#import "AwfulPage.h"
#import "AwfulPost.h"
#import "NSString+HTML.h"
#import "AwfulReplyRequest.h"
#import "AwfulNavigator.h"
#import "AwfulAppDelegate.h"

@implementation AwfulEditRequest

@synthesize post = _post;
@synthesize text = _text;

-(id)initWithAwfulPost : (AwfulPost *)post withText : (NSString *)post_text
{
    NSURL *edit_url = [NSURL URLWithString:[NSString stringWithFormat:@"http://forums.somethingawful.com/editpost.php?action=editpost&postid=%@", post.postID]];
    self = [super initWithURL:edit_url];
    self.userInfo = [NSDictionary dictionaryWithObject:@"Editing..." forKey:@"loadingMsg"];
    
    _post = post;
    _text = post_text;
    return self;
}


-(void)requestFinished
{
    [super requestFinished];
    
    NSURL *edit_url = [NSURL URLWithString:@"http://forums.somethingawful.com/editpost.php"];
    
    CloserFormRequest *form = [CloserFormRequest requestWithURL:edit_url];
    form.post = self.post;
    form.userInfo = [NSDictionary dictionaryWithObject:@"Editing..." forKey:@"loadingMsg"];
    
    NSString *raw_s = [[NSString alloc] initWithData:[self responseData] encoding:NSASCIIStringEncoding];
    NSData *converted = [raw_s dataUsingEncoding:NSUTF8StringEncoding];
    
    TFHpple *page_data = [[TFHpple alloc] initWithHTMLData:converted];
    TFHppleElement *bookmark_element = [page_data searchForSingle:@"//input[@name='bookmark' and @checked='checked']"];
    if(bookmark_element != nil) {
        NSString *bookmark = [bookmark_element objectForKey:@"value"];
        [form addPostValue:bookmark forKey:@"bookmark"];
    }
    
    [form addPostValue:@"updatepost" forKey:@"action"];
    [form addPostValue:@"Save Changes" forKey:@"submit"];
    [form addPostValue:self.post.postID forKey:@"postid"];
    [form addPostValue:[self.text stringByEscapingUnicode] forKey:@"message"];
    
    loadRequestAndWait(form);
}

-(void)failWithError:(NSError *)theError
{
    [super failWithError:theError];
}

@end

@implementation AwfulEditContentRequest

@synthesize post = _post;

-(id)initWithAwfulPost : (AwfulPost *)post
{
    NSURL *edit_url = [NSURL URLWithString:[NSString stringWithFormat:@"http://forums.somethingawful.com/editpost.php?action=editpost&postid=%@", post.postID]];
    self = [super initWithURL:edit_url];
    
    _post = post;
    
    return self;
}


-(void)requestFinished
{
    NSString *raw_s = [[NSString alloc] initWithData:[self responseData] encoding:NSASCIIStringEncoding];
    NSData *converted = [raw_s dataUsingEncoding:NSUTF8StringEncoding];

    TFHpple *base = [[TFHpple alloc] initWithHTMLData:converted];
    TFHppleElement *quote_el = [base searchForSingle:@"//textarea[@name='message']"];
    
    [AwfulPostBoxController clearStoredPost];
    AwfulPostBoxController *post_box = [[AwfulPostBoxController alloc] initWithText:[NSString stringWithFormat:@"%@\n", [quote_el content]]];
    post_box.post = self.post;
    
    UIViewController *vc = getRootController();
    [vc presentModalViewController:post_box animated:YES];
    
}

@end