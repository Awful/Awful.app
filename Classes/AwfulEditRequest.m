//
//  AwfulEditRequest.m
//  Awful
//
//  Created by Sean Berry on 11/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulEditRequest.h"
#import "AwfulNavController.h"
#import "AwfulPostBoxController.h"
#import "NSString+HTML.h"

@implementation AwfulEditRequest

-(id)initWithAwfulPost : (AwfulPost *)in_post withText : (NSString *)post_text
{
    NSURL *edit_url = [NSURL URLWithString:[NSString stringWithFormat:@"http://forums.somethingawful.com/editpost.php?action=editpost&postid=%@", in_post.postID]];
    self = [super initWithURL:edit_url];
    
    post = [in_post retain];
    text = [post_text retain];
    return self;
}

-(void)dealloc
{
    [post release];
    [text release];
    [super dealloc];
}

-(void)requestFinished
{
    NSURL *edit_url = [NSURL URLWithString:@"http://forums.somethingawful.com/editpost.php"];
    ASIFormDataRequest *form = [ASIFormDataRequest requestWithURL:edit_url];
    
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
    [form addPostValue:post.postID forKey:@"postid"];
    [form addPostValue:[text stringByEscapingUnicode] forKey:@"message"];
    
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:self.userInfo];
    
    form.userInfo = dict;
    
    AwfulNavController *nav = getnav();
    [nav loadRequestAndWait:form];
}

@end

@implementation AwfulEditContentRequest

-(id)initWithAwfulPage : (AwfulPage *)in_page forAwfulPost : (AwfulPost *)in_post
{
    NSURL *edit_url = [NSURL URLWithString:[NSString stringWithFormat:@"http://forums.somethingawful.com/editpost.php?action=editpost&postid=%@", in_post.postID]];
    self = [super initWithURL:edit_url];
    
    page = [in_page retain];
    post = [in_post retain];
    
    return self;
}

-(void)dealloc
{
    [page release];
    [post release];
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
    [post_box setEditBox:post];
    
    AwfulNavController *nav = getnav();
    [nav presentModalViewController:post_box animated:YES];
    [post_box release];
    
    [base release];
}

@end