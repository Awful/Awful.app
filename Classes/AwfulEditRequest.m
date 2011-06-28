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

@implementation AwfulEditRequest

@synthesize post = _post;
@synthesize text = _text;

-(id)initWithAwfulPost : (AwfulPost *)post withText : (NSString *)post_text
{
    NSURL *edit_url = [NSURL URLWithString:[NSString stringWithFormat:@"http://forums.somethingawful.com/editpost.php?action=editpost&postid=%@", post.postID]];
    self = [super initWithURL:edit_url];
    
    _post = [post retain];
    _text = [post_text retain];
    return self;
}

-(void)dealloc
{
    [_post release];
    [_text release];
    [super dealloc];
}

-(void)requestFinished
{
    [super requestFinished];
    
    NSURL *edit_url = [NSURL URLWithString:@"http://forums.somethingawful.com/editpost.php"];
    CloserFormRequest *form = [CloserFormRequest requestWithURL:edit_url];
    
    form.post = self.post;
    
    NSString *raw_s = [[NSString alloc] initWithData:[self responseData] encoding:NSASCIIStringEncoding];
    NSData *converted = [raw_s dataUsingEncoding:NSUTF8StringEncoding];
    
    TFHpple *page_data = [[TFHpple alloc] initWithHTMLData:converted];
    [raw_s release];
    TFHppleElement *bookmark_element = [page_data searchForSingle:@"//input[@name='bookmark' and @checked='checked']"];
    if(bookmark_element != nil) {
        NSString *bookmark = [bookmark_element objectForKey:@"value"];
        [form addPostValue:bookmark forKey:@"bookmark"];
    }
    [page_data release];
    
    [form addPostValue:@"updatepost" forKey:@"action"];
    [form addPostValue:@"Save Changes" forKey:@"submit"];
    [form addPostValue:self.post.postID forKey:@"postid"];
    [form addPostValue:[self.text stringByEscapingUnicode] forKey:@"message"];
    
    loadRequestAndWait(form);
}

@end

@implementation AwfulEditContentRequest

@synthesize post = _post;

-(id)initWithAwfulPost : (AwfulPost *)post
{
    NSURL *edit_url = [NSURL URLWithString:[NSString stringWithFormat:@"http://forums.somethingawful.com/editpost.php?action=editpost&postid=%@", post.postID]];
    self = [super initWithURL:edit_url];
    
    _post = [post retain];
    
    return self;
}

-(void)dealloc
{
    [_post release];
    [super dealloc];
}

-(void)requestFinished
{
    NSString *raw_s = [[NSString alloc] initWithData:[self responseData] encoding:NSASCIIStringEncoding];
    NSData *converted = [raw_s dataUsingEncoding:NSUTF8StringEncoding];
    [raw_s release];

    TFHpple *base = [[TFHpple alloc] initWithHTMLData:converted];
    TFHppleElement *quote_el = [base searchForSingle:@"//textarea[@name='message']"];
    
    AwfulPostBoxController *post_box = [[AwfulPostBoxController alloc] initWithText:[NSString stringWithFormat:@"%@\n", [quote_el content]]];
    post_box.post = self.post;
    
    AwfulNavigator *nav = getNavigator();
    [nav presentModalViewController:post_box animated:YES];
    [post_box release];
    
    [base release];
}

@end