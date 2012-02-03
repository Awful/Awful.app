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

@implementation AwfulPageTemplate

@synthesize mainHTML = _mainHTML;
@synthesize modImageHTML = _modImageHTML;
@synthesize adminImageHTML = _adminImageHTML;
@synthesize postActionImageHTML = _postActionImageHTML;

+(NSString *)parseYouTubes : (NSString *)html
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

+(NSString *)parseOutImages : (NSString *)html
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

-(NSString *)constructHTMLForPost : (AwfulPost *)post
{    
    NSString *parsed_post_body = post.postBody;
    
    if(![AwfulConfig showImages]) {
        parsed_post_body = [self parseOutImages:parsed_post_body];
    }
    parsed_post_body = [self parseEmbeddedVideos:parsed_post_body];
    parsed_post_body = [parsed_post_body stringByReplacingOccurrencesOfString:@"&#13;" withString:@""];
    
    self.mainHTML = @"<table id='%POST_ID%' class='userbox %OP%'><tr><td class='avatar_td'><img class='avatar_img' src='%AVATAR_URL%'/></td><td class='name_date_box'><span class='username %OP%'>%MOD_IMAGE%%ADMIN_IMAGE%%POSTER_NAME%</span><br/><span class='post_date'>Posted on %POST_DATE%</span></td><td></td><td class='quotebutton' onclick=tappedPost('%POST_ID%')>%POST_ACTION_IMAGE%</td></tr></table><div class='postbodymain %ALT_CLASS%'><div class='postbodysub'>%POST_BODY%</div></div>";
    
    NSString *html = [self.mainHTML stringByReplacingOccurrencesOfString:@"%POST_ID%" withString:post.postID];
    html = [html stringByReplacingOccurrencesOfString:@"%POST_DATE%" withString:post.postDate];
    html = [html stringByReplacingOccurrencesOfString:@"%ALT_CLASS%" withString:post.altCSSClass];
    
    if(post.isOP) {
        html = [html stringByReplacingOccurrencesOfString:@"%OP%" withString:@"op"];
    } else {
        html = [html stringByReplacingOccurrencesOfString:@"%OP%" withString:@""];
    }
    
    if(post.posterType == AwfulUserTypeMod) {
        html = [html stringByReplacingOccurrencesOfString:@"%MOD_IMAGE%" withString:self.modImageHTML];
    } else {
        html = [html stringByReplacingOccurrencesOfString:@"%MOD_IMAGE%" withString:@""];
    }
    
    if(post.posterType == AwfulUserTypeAdmin) {
        html = [html stringByReplacingOccurrencesOfString:@"%ADMIN_IMAGE%" withString:self.adminImageHTML];
    } else {
        html = [html stringByReplacingOccurrencesOfString:@"%ADMIN_IMAGE%" withString:@""];
    }
    
    /* prevent someone from naming themselves %POST_BODY% and messing up the format
    // the alternative was to let users put %POSTER_NAME% in their post body and have it sub in their name
    // this way only a guy named %POST_BODY% will have a slightly altered name */
    NSString *parsed_name = [post.posterName stringByReplacingOccurrencesOfString:@"%POST_BODY%" withString:@"POST_BODY"];
    html = [html stringByReplacingOccurrencesOfString:@"%POSTER_NAME%" withString:parsed_name];
    html = [html stringByReplacingOccurrencesOfString:@"%POST_BODY%" withString:parsed_post_body];
   
    return html;
}

@end


/* Notes. An element needs the %POST_ID% so it knows where to scroll down to for the 'newest post'.

 If the post if made by the OP, %OP% will insert the value, otherwise it will just leave it blank
 %AVATAR_URL% puts in the full url
 %MOD_IMAGE% inserts the html for ModImage, or nothing if they're not a mod. Same with %ADMIN_IMAGE%
 personal note, put in &nbsp; after the mod image to have a space in my template

%POSTER_NAME%, %POST_DATE%, %POST_BODY% are self explanatory
 
tappedPost('%POST_ID') is some javascript that will call the post actions in the app.
 
for the _IMAGE ones... get to specify the image and the css class. it will convert it to base64 and proper <img thing when saving>
 
%POST_IMAGE% is the html that puts in the 
 
%ALT_CLASS% inserts either 'altcolor1', 'altcolor2', 'seen1', or 'seen2' depending on the post index (even/odd) and also if they're seen it or not. The default is blue for seen.

*/