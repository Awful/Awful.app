//
//  AwfulPageTemplate.m
//  Awful
//
//  Created by Sean Berry on 2/3/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulPageTemplate.h"
#import "AwfulPost.h"
#import "TFHpple.h"
#import "TFHppleElement.h"
#import "AwfulConfig.h"
#import "AwfulPageDataController.h"
#import "AwfulPageCount.h"
#import "SALR.h"

@implementation AwfulPageTemplate

@synthesize mainHTML = _mainHTML;
@synthesize postHTML = _postHTML;

-(id)initWithTemplateString : (NSString *)html
{
    if((self=[super init])) {
        _mainHTML = html;
    }
    return self;
}
-(NSString *)parseEmbeddedVideos : (NSString *)html
{
    TFHpple *base = [[TFHpple alloc] initWithHTMLData:[html dataUsingEncoding:NSUTF8StringEncoding]];
    NSString *parsed = html;
    
    NSArray *objects = [base search:@"//object/param[@name='movie']"];
    NSArray *object_strs = [base rawSearch:@"//object"];
    
    for(int i = 0; i < [objects count]; i++) {
        TFHppleElement *el = [objects objectAtIndex:i];
        NSRange r = [[el objectForKey:@"value"] rangeOfString:@"youtube"];
        if(r.location != NSNotFound) {
            NSURL *youtube_url = [NSURL URLWithString:[el objectForKey:@"value"]];
            
            NSString *youtube_str = [NSString stringWithFormat:@"http://www.youtube.com/watch?v=%@", [youtube_url lastPathComponent]];
            NSString *reformed_youtube = [NSString stringWithFormat:@"<a href='%@'>Embedded YouTube</a>", youtube_str];
            if(i < [object_strs count]) {
                parsed = [parsed stringByReplacingOccurrencesOfString:[object_strs objectAtIndex:i] withString:reformed_youtube];
            }
        } else {
            r = [[el objectForKey:@"value"] rangeOfString:@"vimeo"];
            if(r.location != NSNotFound) {
                NSRange clip = [[el objectForKey:@"value"] rangeOfString:@"clip_id="];
                NSRange and = [[el objectForKey:@"value"] rangeOfString:@"&"];
                NSRange clip_range;
                clip_range.location = clip.location + 8;
                clip_range.length = and.location - clip.location - 8;
                NSString *clip_id = [[el objectForKey:@"value"] substringWithRange:clip_range];
                NSString *reformed_vimeo = [NSString stringWithFormat:@"<a href='http://www.vimeo.com/m/#/%@'>Embedded Vimeo</a>", clip_id];
                parsed = [parsed stringByReplacingOccurrencesOfString:[object_strs objectAtIndex:i] withString:reformed_vimeo];
            }
        }
    }
    
    return parsed;
}

-(NSString *)parseOutImages : (NSString *)html
{
    TFHpple *base = [[TFHpple alloc] initWithHTMLData:[html dataUsingEncoding:NSUTF8StringEncoding]];
    NSString *parsed = html;
    
    NSArray *objects = [base search:@"//img"];
    NSArray *object_strs = [base rawSearch:@"//img"];
    
    for(int i = 0; i < [objects count]; i++) {
        TFHppleElement *el = [objects objectAtIndex:i];
        NSString *src = [el objectForKey:@"src"];
        NSString *reformed = [NSString stringWithFormat:@"<a href='%@'>IMG LINK</a>", src];
        parsed = [parsed stringByReplacingOccurrencesOfString:[object_strs objectAtIndex:i] withString:reformed];
    }
    
    return parsed;
}

-(NSString *)getPostActionImageHTML
{
    return @"<img class='postaction' src='http://www.regularberry.com/awful/post-action-icon.png'/>";
}

-(NSString *)getModImageHTML
{
    return @"<img src='http://www.regularberry.com/awful/star_moderator.gif'/>&nbsp;";
}

-(NSString *)getAdminImageHTML
{
    return @"<img src='http://www.regularberry.com/awful/star_admin.gif'/>&nbsp;";
}

-(NSString *)constructHTMLForPost : (AwfulPost *)post withPostTemplate : (NSString *)postTemplate
{    
    NSString *parsed_post_body = post.postBody;
    
    if(![AwfulConfig showImages]) {
        parsed_post_body = [self parseOutImages:parsed_post_body];
    }
    parsed_post_body = [self parseEmbeddedVideos:parsed_post_body];
    parsed_post_body = [parsed_post_body stringByReplacingOccurrencesOfString:@"&#13;" withString:@""];
    
    NSString *html = [postTemplate stringByReplacingOccurrencesOfString:@"{%POST_ID%}" withString:post.postID];
        
    if(post.avatarURL == nil || ![AwfulConfig showAvatars]) {
        html = [html stringByTrimmingBetweenBeginString:@"{%AVATAR_BEGIN%}" endString:@"{%AVATAR_END%}"];
    } else {
        html = [html stringByRemovingStrings:@"{%AVATAR_BEGIN%}", @"{%AVATAR_END%}", nil];
        html = [html stringByReplacingOccurrencesOfString:@"{%AVATAR_URL%}" withString:[post.avatarURL absoluteString]];
    }
    
    html = [html stringByReplacingOccurrencesOfString:@"{%POST_DATE%}" withString:post.postDate];
    html = [html stringByReplacingOccurrencesOfString:@"{%ALT_CLASS%}" withString:post.altCSSClass];
    
    if(post.isOP) {
        html = [html stringByReplacingOccurrencesOfString:@"{%OP%}" withString:@"op"];
    } else {
        html = [html stringByReplacingOccurrencesOfString:@"{%OP%}" withString:@""];
    }
    
    if(post.posterType == AwfulUserTypeMod) {
        html = [html stringByRemovingStrings:@"{%MOD_BEGIN%}", @"{%MOD_END%}", nil];
    } else {
        html = [html stringByTrimmingBetweenBeginString:@"{%MOD_BEGIN%}" endString:@"{%MOD_END%}"];
    }
    
    if(post.posterType == AwfulUserTypeAdmin) {
        html = [html stringByRemovingStrings:@"{%ADMIN_BEGIN%}", @"{%ADMIN_END%}", nil];
    } else {
        html = [html stringByTrimmingBetweenBeginString:@"{%ADMIN_BEGIN%}" endString:@"{%ADMIN_END%}"];
    }
        
    /* prevent someone from naming themselves %POST_BODY% and messing up the format
    // the alternative was to let users put %POSTER_NAME% in their post body and have it sub in their name
    // this way only a guy named %POST_BODY% will have a slightly altered name */
    NSString *parsed_name = [post.posterName stringByReplacingOccurrencesOfString:@"{%POST_BODY%}" withString:@"POST_BODY"];
    html = [html stringByReplacingOccurrencesOfString:@"{%POSTER_NAME%}" withString:parsed_name];
    html = [html stringByReplacingOccurrencesOfString:@"{%POST_BODY%}" withString:parsed_post_body];
   
    return html;
}

-(NSString *)constructHTMLFromPageDataController : (AwfulPageDataController *)dataController
{
    NSString *pages_left_str = @"";
    NSUInteger pages_left = [dataController.pageCount getPagesLeft];
    if(pages_left > 1) {
        pages_left_str = [NSString stringWithFormat:@"%d pages left.", pages_left];
    } else if(pages_left == 1) {
        pages_left_str = @"1 page left.";
    } else {
        pages_left_str = @"End of the thread.";
    }
    
    NSString *js = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"jquery" ofType:@"js"] encoding:NSUTF8StringEncoding error:nil];
    
    NSString *salr = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"salr" ofType:@"js"] encoding:NSUTF8StringEncoding error:nil];
    
    js = [js stringByAppendingString:salr];
        
    // Fire off SALR
    NSString *salr_config = [SALR config];
    NSString *salrOpts = @"";
    if(![salr_config isEqualToString:@""]) {
        salrOpts = [NSString stringWithFormat:@"$(document).ready(function() { new SALR(%@); });", salr_config];
    }
    
    NSString *post_template = [self.mainHTML substringBetweenBeginString:@"{%POSTS_BEGIN%}" endString:@"{%POSTS_END%}"];
    
    NSString *combined = @"";
    for(AwfulPost *post in dataController.posts) {
        combined = [combined stringByAppendingString:[self constructHTMLForPost:post withPostTemplate:post_template]];
    }
    
    NSString *html = [self.mainHTML stringByReplacingOccurrencesOfString:@"{%JAVASCRIPT%}" withString:js];
    html = [html stringByReplacingOccurrencesOfString:@"{%SALR_EXECUTION%}" withString:salrOpts];
    html = [html stringByReplacingOccurrencesOfString:@"{%PAGES_LEFT_MESSAGE%}" withString:pages_left_str];
    html = [html stringByReplacingOccurrencesOfString:@"{%USER_AD%}" withString:dataController.userAd];
    
    NSRange posts_begin = [html rangeOfString:@"{%POSTS_BEGIN%}"];
    html = [html stringByTrimmingBetweenBeginString:@"{%POSTS_BEGIN%}" endString:@"{%POSTS_END%}"];
    NSString *before = [html substringToIndex:posts_begin.location];
    NSString *after = [html substringFromIndex:posts_begin.location];
    html = [NSString stringWithFormat:@"%@%@%@", before, combined, after];
    
    return html;
}

@end

@implementation NSString (AwfulAdditions)

-(NSString *)stringByTrimmingBetweenBeginString : (NSString *)beginString endString : (NSString *)endString
{
    NSRange begin_range = [self rangeOfString:beginString];
    NSRange end_range = [self rangeOfString:endString];
    NSRange content_range = NSMakeRange(begin_range.location, (end_range.location - begin_range.location) + end_range.length);
    return [self stringByReplacingCharactersInRange:content_range withString:@""];
}

-(NSString *)stringByRemovingStrings : (NSString *)first, ...
{
    NSString *content = self;
    va_list args;
    va_start(args, first);
    for(NSString *str = first; str != nil; str = va_arg(args, NSString *)) {
        content = [content stringByReplacingOccurrencesOfString:str withString:@""];
    }
    va_end(args);
    return content;
}

-(NSString *)substringBetweenBeginString : (NSString *)beginString endString : (NSString *)endString
{
    NSRange begin_range = [self rangeOfString:beginString];
    NSRange end_range = [self rangeOfString:endString];
    if(begin_range.location != NSNotFound && end_range.location != NSNotFound) {
        NSRange content_range = NSMakeRange(begin_range.location+begin_range.length, end_range.location - (begin_range.location+begin_range.length));
        if(content_range.location + content_range.length <= [self length]) {
            return [self substringWithRange:content_range];
        }
    }
    return @"";
}

@end


/* Notes:
 
 One element needs an id of {%POST_ID%} so the app knows where to scroll down to for the 'newest post'.

 If the post if made by the OP, {%OP%} will insert 'op' (without the ''), otherwise it will just leave it blank
 {%MOD_BEGIN%} --- {%MOD_END%} will insert that html if the poster is a mod, same with {%ADMIN_BEGIN%} -- {%ADMIN_END%]
 Same with {%AVATAR_BEGIN%} etc... nothing will be put in if they don't have an avatar or if they have avatars turned off in settings.
 {%AVATAR_URL%} puts in the full url

{%POSTER_NAME%}, {%POST_DATE%}, {%POST_BODY%} are self explanatory
 
tappedPost('{%POST_ID%}') is some javascript that will show the post actions in the app. E.g. 'Quote', 'Mark up to here', etc...
 
{%ALT_CLASS%} inserts either 'altcolor1', 'altcolor2', 'seen1', or 'seen2' depending on the post index (even/odd)
 
{%PAGES_LEFT_MESSAGE%} is either 'x pages left.' '1 page left.' or 'End of the thread.'

the tappedBottom() javascript triggers a 'next page' call if there are pages left
 
{%JAVASCRIPT%} inserts those functions I need
{%SALR_EXECUTION%} is for SALR
 
 {%POSTS_BEGIN%} - {%POSTS_END%} will iterate over all of the posts using the template specified between POSTS_BEGIN/POSTS_END
 
{%USER_AD%} inserts the user ad image

*/