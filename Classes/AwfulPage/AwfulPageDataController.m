//
//  AwfulPageDataController.m
//  Awful
//
//  Created by Sean Berry on 2/3/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPageDataController.h"
#import "AwfulForum.h"
#import "AwfulPageCount.h"
#import "TFHpple.h"
#import "TFHppleElement.h"
#import "XPathQuery.h"
#import "AwfulPost.h"
#import "AwfulUtil.h"
#import "AwfulPageTemplate.h"

@interface AwfulPageDataController ()

-(NSString *)parseThreadTitle : (TFHpple *)parser;
-(AwfulForum *)parseForum : (TFHpple *)parser;
-(AwfulPageCount *)parsePageCount : (TFHpple *)parser;
-(NSMutableArray *)parsePosts : (TFHpple *)parser;
-(AwfulPost *)parsePost : (TFHpple *)parser;
-(NSUInteger)parseNewPostIndex : (NSURL *)pageURL;
-(NSString *)parseUserAdHTML : (TFHpple *)parser;

@end

@implementation AwfulPageDataController

@synthesize threadTitle = _threadTitle, forum = _forum;
@synthesize pageCount = _pageCount, posts = _posts;
@synthesize newestPostIndex = _newestPostIndex, userAd = _userAd;

-(id)initWithResponseData : (NSData *)responseData pageURL : (NSURL *)pageURL
{
    if((self=[super init])) {
        NSString *raw_s = [[NSString alloc] initWithData:responseData encoding:NSASCIIStringEncoding];
        NSString *filtered_raw = [raw_s stringByReplacingOccurrencesOfString:@"<size:" withString:@"<"];
        NSData *converted = [filtered_raw dataUsingEncoding:NSUTF8StringEncoding];
        
        TFHpple *page_parser = [[TFHpple alloc] initWithHTMLData:converted];
        _threadTitle = [self parseThreadTitle:page_parser];
        _forum = [self parseForum:page_parser];
        _pageCount = [self parsePageCount:page_parser];
        _posts = [self parsePosts:page_parser];
        _newestPostIndex = [self parseNewPostIndex:pageURL];
        _userAd = [self parseUserAdHTML:page_parser];
    }
    return self;
}

-(NSString *)parseThreadTitle : (TFHpple *)parser
{
    TFHppleElement *thread_title = [parser searchForSingle:@"//a[@class='bclast']"];
    if(thread_title != nil) {
        return [thread_title content];
    }
    return @"Title Not Found";
}

-(AwfulForum *)parseForum : (TFHpple *)parser
{
    NSArray *breadcrumbs = [parser search:@"//div[@class='breadcrumbs']//a"];
    NSString *last_forum_id = nil;
    for(TFHppleElement *element in breadcrumbs) {
        NSString *src = [element objectForKey:@"href"];
        NSRange range = [src rangeOfString:@"forumdisplay.php"];
        if(range.location != NSNotFound) {
            NSArray *split = [src componentsSeparatedByString:@"="];
            last_forum_id = [split lastObject];
        }
    }
    
    if(last_forum_id != nil) {
        AwfulForum *forum = [AwfulForum awfulForumFromID:last_forum_id];
        return forum;
    }
    return nil;
}

-(AwfulPageCount *)parsePageCount : (TFHpple *)parser
{
    AwfulPageCount *pages = [[AwfulPageCount alloc] init];
    
    NSArray *strings = PerformRawHTMLXPathQuery(parser.data, @"//div[@class='pages top']");
    if(strings != nil && [strings count] > 0) {
        // this is going to get me in trouble one day
        NSString *page_info = [strings objectAtIndex:0];
        NSRange first_paren = [page_info rangeOfString:@"("];
        
        if(first_paren.location != NSNotFound) {
            NSRange last_paren = [page_info rangeOfString:@")"];
            NSRange combined;
            combined.location = first_paren.location + 1;
            combined.length = last_paren.location - first_paren.location - 1;
            NSString *total_pages_str = [page_info substringWithRange:combined];
            pages.totalPages = [total_pages_str intValue];
            
            TFHpple *base = [[TFHpple alloc] initWithHTMLData:[page_info dataUsingEncoding:NSUTF8StringEncoding]];
            TFHppleElement *curpage = [base searchForSingle:@"//span[@class='curpage']"];
            if(curpage != nil) {
                pages.currentPage = [[curpage content] intValue];
            }
        } else {
            pages.totalPages = 1;
            pages.currentPage = 1;
        }
    }
    return pages;
}

-(NSMutableArray *)parsePosts : (TFHpple *)parser
{
    NSArray *post_strings = PerformRawHTMLXPathQuery(parser.data, @"//table[@class='post']|//table[@class='post ignored']");
    
    NSMutableArray *parsed_posts = [[NSMutableArray alloc] init];
    
    for(NSString *post_html in post_strings) {
        @autoreleasepool {
            TFHpple *post_base = [[TFHpple alloc] initWithHTMLData:[post_html dataUsingEncoding:NSUTF8StringEncoding]];
            AwfulPost *post = [self parsePost:post_base];
            post.postIndex = [post_strings indexOfObject:post_html];
            [parsed_posts addObject:post];
        }
    }
    return parsed_posts;
}

-(AwfulPost *)parsePost : (TFHpple *)parser
{
    NSString *username = getUsername();
    
    AwfulPost *post = [[AwfulPost alloc] init];
    
    NSString *username_search = @"//dt[@class='author']|//dt[@class='author op']|//dt[@class='author role-mod']|//dt[@class='author role-admin']|//dt[@class='author role-mod op']|//dt[@class='author role-admin op']";
    
    TFHppleElement *author = [parser searchForSingle:username_search];
    if(author != nil) {
        post.posterName = [author content];
        NSString *author_class = [author objectForKey:@"class"];
        if([author_class isEqualToString:@"author op"] || [author_class isEqualToString:@"author role-admin op"] || [author_class isEqualToString:@"author role-mod op"]) {
            post.isOP = YES;
        } else {
            post.isOP = NO;
        }
        
        TFHppleElement *mod = [parser searchForSingle:@"//dt[@class='author role-mod']|//dt[@class='author role-mod op']"];
        if(mod != nil) {
            post.posterType = AwfulUserTypeMod;
        }
        
        TFHppleElement *admin = [parser searchForSingle:@"//dt[@class='author role-admin']|//dt[@class='author role-admin op']"];
        if(admin != nil) {
            post.posterType = AwfulUserTypeAdmin;
        }
        
        if([post.posterName isEqualToString:username]) {
            post.canEdit = YES;
        }
    }
    
    TFHppleElement *post_id = [parser searchForSingle:@"//table[@class='post']|//table[@class='post ignored']"];
    if(post_id != nil) {
        NSString *post_id_str = [post_id objectForKey:@"id"];
        post.postID = [post_id_str substringFromIndex:4];
    }
    
    TFHppleElement *post_date = [parser searchForSingle:@"//td[@class='postdate']"];
    if(post_date != nil) {
        post.postDate = [post_date content];
    }
    
    TFHppleElement *seen_link = [parser searchForSingle:@"//td[@class='postdate']//a[@title='Mark thread seen up to this post']"];
    if(seen_link != nil) {
        post.markSeenLink = [seen_link objectForKey:@"href"];
    }
    
    TFHppleElement *avatar = [parser searchForSingle:@"//dd[@class='title']//img"];
    if(avatar != nil) {
        post.avatarURL = [NSURL URLWithString:[avatar objectForKey:@"src"]];
    }
    
    TFHppleElement *edited = [parser searchForSingle:@"//p[@class='editedby']/span"];
    if(edited != nil) {
        post.editedStr = [[edited content] stringByReplacingOccurrencesOfString:@"fucked around with this message" withString:@"edited"];
    }
    
    NSString *body_search_str = @"//td[@class='postbody']";
    /*if(is_fyad) {
     body_search_str = @"//div[@class='complete_shit funbox']";
     } else {
     body_search_str = @"//td[@class='postbody']";
     }*/
    
    NSArray *body_strings = [parser rawSearch:body_search_str];
    
    if([body_strings count] == 1) {
        NSString *post_body = [body_strings objectAtIndex:0];
        post.postBody = post_body;
        
        TFHppleElement *seen = [parser searchForSingle:@"//tr[@class='seen1']|//tr[@class='seen2']"];
        post.seen = (seen != nil);
    }
    
    return post;
}

-(NSUInteger)parseNewPostIndex:(NSURL *)pageURL
{
    NSString *frag = [pageURL fragment];
    if(frag != nil) {
        NSRange r = [frag rangeOfString:@"pti"];
        if(r.location == 0) {
            NSString *new_post = [frag stringByReplacingOccurrencesOfString:@"pti" withString:@""];
            return [new_post integerValue]-1;
        }
    }
    return 0;
}

-(NSString *)parseUserAdHTML:(TFHpple *)parser
{
    NSArray *raws = [parser rawSearch:@"//div[@id='ad_banner_user']/a"];
    if([raws count] > 0) {
        return [raws objectAtIndex:0];
    }
    
    return @"";
}

-(NSString *)constructedPageHTML
{
    NSString *html = nil;
    
    NSUbiquitousKeyValueStore *keyStore = [NSUbiquitousKeyValueStore defaultStore];
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone && [keyStore objectForKey:@"phone-template"]) {
        html = [keyStore objectForKey:@"phone-template"];
    } else if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && [keyStore objectForKey:@"pad-template"]) {
        html = [keyStore objectForKey:@"pad-template"];
    }
    
    if(html == nil) {
        NSString *filename = @"phone-template";
        if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            filename = @"pad-template";
        }
    
        html = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:filename ofType:@"html"] encoding:NSUTF8StringEncoding error:nil];
    }
    

    AwfulPageTemplate *template = [[AwfulPageTemplate alloc] initWithTemplateString:html];
    return [template constructHTMLFromPageDataController:self];
}

-(NSString *)calculatePostIDScrollDestination
{    
    if(self.newestPostIndex < [self.posts count]) {
        AwfulPost *post = [self.posts objectAtIndex:self.newestPostIndex];
        return post.postID;
    }
    return nil;
}

-(BOOL)shouldScrollToBottom
{
    return self.newestPostIndex == [self.posts count];
}

@end
