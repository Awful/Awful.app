//
//  AwfulParse.m
//  Awful
//
//  Created by Sean Berry on 10/7/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulParse.h"
#import "XPathQuery.h"
#import "AwfulThread.h"
#import "AwfulPage.h"
#import "AwfulConfig.h"
#import "AwfulPost.h"
#import "TFHpple.h"
#import "AwfulPageCount.h"
#import "AwfulUtil.h"
#import "SALR.h"

@implementation AwfulParse

+(NSString *)constructPostHTML : (AwfulPost *)post withBody : (NSString *)post_body alt : (NSString *)alt
{
   /* NSString *avatar_str;
    
    if(post.avatarURL == nil) {
        avatar_str = @"";
    } else {
        if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
            avatar_str = [NSString stringWithFormat:@"<td class='avatar_td'><img class='avatar_img' src='%@'/></td>", post.avatarURL];
        } else if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            avatar_str = [NSString stringWithFormat:@"<img src='%@' style='max-width:80px;margin:auto'/>", post.avatarURL];
        }
    }
    
    NSString *userbox_str = @"userbox";
    NSString *user_str = @"username";
    if(post.isOP) {
        user_str = @"username_op";
        userbox_str = @"userbox_op";
    }

    NSString *username_info = post.posterName;
    if(post.posterType == AwfulUserTypeAdmin) {
        username_info = [NSString stringWithFormat:@"%@&nbsp;%@", [self getAdminImgHTML], post.posterName];
    } else if(post.posterType == AwfulUserTypeMod) {
        username_info = [NSString stringWithFormat:@"%@&nbsp;%@", [self getModImgHTML], post.posterName];
    }
    
    NSString *parsed_post_body = [AwfulParse parseYouTubes:post_body];
    
    if(![AwfulConfig showImages]) {
        parsed_post_body = [AwfulParse parseOutImages:parsed_post_body];
    }
    parsed_post_body = [parsed_post_body stringByReplacingOccurrencesOfString:@"&#13;" withString:@""];
    
    NSString *html = nil;
    
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        
        NSString *name_avatar_box = [NSString stringWithFormat:@"<table id='%@' class='%@'><tr>%@<td class='name_date_box'><span class='%@'>%@</span><br/><span class='post_date'>Posted on %@</span></td><td></td><td class='quotebutton' onclick=tappedPost('%@')>%@</td></tr></table>", post.postID, userbox_str, avatar_str, user_str, username_info, post.postDate, post.postID, [AwfulParse getPostActionHTML]];
        
        html = [NSString stringWithFormat:@"%@<div class='postbodymain %@'><div class='postbodysub'>%@</div></div>", name_avatar_box, alt, parsed_post_body];
        
    } else if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        html = [NSString stringWithFormat:@"<div class='postbodymain %@' style='padding:10px'><table id='%@'><tr><td valign='top' width=100px rowspan=3>%@</td><td valign='top'><span class='%@'>%@</span></td><td class='quotebutton' onclick=tappedPost('%@')>%@</td></tr><tr>%@</tr><tr><td><span class='post_date'>Posted On %@</span></td></tr></table></div>", 
                alt, post.postID, avatar_str, user_str, username_info, post.postID, [AwfulParse getPostActionHTML], parsed_post_body, post.postDate];
    }
        
    return html;*/
    return @"";
}

+(NSString *)constructPageHTMLFromPosts : (NSMutableArray *)posts pagesLeft : (int)pages_left numOldPosts : (int)num_above adHTML : (NSString *)adHTML
{
    /*
    NSString *combined = @"";
    for(AwfulPost *post in posts) {
        combined = [combined stringByAppendingString:post.formattedHTML];
    }
    
    NSString *pages_left_str = @"";
    if(pages_left > 1) {
        pages_left_str = [NSString stringWithFormat:@"%d pages left.", pages_left];
    } else if(pages_left == 1) {
        pages_left_str = @"1 page left.";
    } else {
        pages_left_str = @"End of the thread.";
    }
    
    NSString *top = @"";
    if(num_above > 0) {
        NSString *above_str = @"";
        if(num_above == 1) {
            above_str = @"1 post above.";
        } else {
            above_str = [NSString stringWithFormat:@"%d posts above.", num_above];
        }
        top = [NSString stringWithFormat:@"<table class='olderposts'><tr><td onclick=tappedOlderPosts()>%@</td></tr></table>", above_str];
    }
        
    NSString *bottom = [NSString stringWithFormat:@"<div class='pagesleft' onclick=tappedBottom()>%@</div>", pages_left_str];
    
    NSString *css = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"post" ofType:@"css"] encoding:NSUTF8StringEncoding error:nil];
        
    NSString *js = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"jquery" ofType:@"js"] encoding:NSUTF8StringEncoding error:nil];
    
    NSString *salr = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"salr" ofType:@"js"] encoding:NSUTF8StringEncoding error:nil];
    
    NSString *width = @"width=device-width, ";
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        width = @"width=80%, "; //700
    }
    NSString *meta = [NSString stringWithFormat:@"<meta name='viewport' content='%@minimum-scale=1.0, maximum-scale=1.0'>", width];
        
    // Fire off SALR
    NSString *salr_config = [SALR config];
    NSString *salrOpts = @"";
    if(![salr_config isEqualToString:@""]) {
        salrOpts = [NSString stringWithFormat:@"$(document).ready(function() { new SALR(%@); });", salr_config];
    }
    NSString *html = [NSString stringWithFormat:@"<html><head>%@<script type='text/javascript'>%@</script><script type='text/javascript'>%@</script><style type='text/css'>%@</style></head><body><script type='text/javascript'>%@</script>%@%@%@%@</body></html>", 
                    meta, js, salr, css, salrOpts, top, combined, adHTML, bottom];
    
    return html;*/
    return @"";
}

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

+(NSMutableArray *)parseThreadsFromForumData : (NSData *)data
{
    NSString *raw_str = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
    NSData *converted = [raw_str dataUsingEncoding:NSUTF8StringEncoding];
    TFHpple *hpple = [[TFHpple alloc] initWithHTMLData:converted];
    
    NSMutableArray *parsed_threads = [[NSMutableArray alloc] init];

    NSString *reg_str = @"//tr[@class='thread']";
    NSString *reg_category_str = @"//tr[@class='thread category0']|//tr[@class='thread category1']|//tr[@class='thread category2']";
    
    NSString *closed_base_str = @"//tr[@class='thread closed']|//tr[@class='thread seen closed']";
    NSString *closed_category_str = @"//tr[@class='thread seen category0 closed']|//tr[@class='thread seen category1 closed']|//tr[@class='thread seen category2 closed']";
    NSString *closed_str = [closed_base_str stringByAppendingFormat:@"|%@", closed_category_str];
    
    NSString *seen_base_str = @"//tr[@class='thread seen']";
    NSString *seen_category_str = @"//tr[@class='thread seen category0']|//tr[@class='thread seen category1']|//tr[@class='thread seen category2']";
    NSString *seen_str = [seen_base_str stringByAppendingFormat:@"|%@", seen_category_str];
    
    NSString *category_zero = @"//tr[@class='thread category0']|//tr[@class='thread seen category0']";
    NSString *category_one = @"//tr[@class='thread category1']|//tr[@class='thread seen category1']";
    NSString *category_two = @"//tr[@class='thread category2']|//tr[@class='thread seen category2']";
    
    NSString *big_str = [reg_str stringByAppendingFormat:@"|%@|%@|%@", reg_category_str, closed_str, seen_str];

    NSArray *post_strings = PerformRawHTMLXPathQuery(hpple.data, big_str);
    
    for(NSString *thread_html in post_strings) {
    
        @autoreleasepool {
    
            TFHpple *thread_base = [[TFHpple alloc] initWithHTMLData:[thread_html dataUsingEncoding:NSUTF8StringEncoding]];
            
            AwfulThread *thread = [[AwfulThread alloc] init];
            // i can't get the userid easily so scratch that
            
            TFHppleElement *title = [thread_base searchForSingle:@"//a[@class='thread_title']"];
            if(title != nil) {
                thread.title = [title content];
            }
            
            TFHppleElement *sticky = [thread_base searchForSingle:@"//td[@class='title title_sticky']"];
            if(sticky != nil) {
                thread.isStickied = YES;
            }
            
            TFHppleElement *icon = [thread_base searchForSingle:@"//td[@class='icon']/img"];
            if(icon != nil) {
                NSString *icon_str = [icon objectForKey:@"src"];
                thread.threadIconImageURL = [NSURL URLWithString:icon_str];
            }
            
            TFHppleElement *author = [thread_base searchForSingle:@"//td[@class='author']/a"];
            if(author != nil) {
                thread.authorName = [author content];
            }
            
            TFHppleElement *tid = [thread_base searchForSingle:big_str];
            if(tid != nil) {
                NSString *tid_str = [tid objectForKey:@"id"];
                if(tid_str == nil) {
                    // announcements don't have thread_ids, they get linked to announcement.php
                    // gonna disregard announcements for now
                    continue;
                } else {
                    thread.threadID = [tid_str substringFromIndex:6];
                }
            }
            
            TFHppleElement *seen = [thread_base searchForSingle:seen_str];
            if(seen != nil) {
                thread.seen = YES;
            }
            
            TFHppleElement *locked = [thread_base searchForSingle:closed_str];
            if(locked != nil) {
                thread.isLocked = YES;
            }
            
            TFHppleElement *cat_zero = [thread_base searchForSingle:category_zero];
            if(cat_zero != nil) {
                thread.starCategory = AwfulStarCategoryBlue;
            }
            
            TFHppleElement *cat_one = [thread_base searchForSingle:category_one];
            if(cat_one != nil) {
                thread.starCategory = AwfulStarCategoryRed;
            }
            
            TFHppleElement *cat_two = [thread_base searchForSingle:category_two];
            if(cat_two != nil) {
                thread.starCategory = AwfulStarCategoryYellow;
            }
            
            TFHppleElement *unread = [thread_base searchForSingle:@"//a[@class='count']/b"];
            if(unread != nil) {
                NSString *unread_str = [unread content];
                thread.totalUnreadPosts = [unread_str intValue];
            } else {
                unread = [thread_base searchForSingle:@"//a[@class='x']"];
                if(unread != nil) {
                    // they've read it all
                    thread.totalUnreadPosts = 0;
                }
            }
            
            TFHppleElement *total = [thread_base searchForSingle:@"//td[@class='replies']/a"];
            if(total != nil) {
                thread.totalReplies = [[total content] intValue];
            } else {
                total = [thread_base searchForSingle:@"//td[@class='replies']"];
                if(total != nil) {
                    thread.totalReplies = [[total content] intValue];
                }
            }
            
            TFHppleElement *rating = [thread_base searchForSingle:@"//td[@class='rating']/img"];
            if(rating != nil) {
                NSString *rating_str = [rating objectForKey:@"src"];
                NSURL *rating_url = [NSURL URLWithString:rating_str];
                NSString *last = [rating_url lastPathComponent];
                if([last isEqualToString:@"5stars.gif"]) {
                    thread.threadRating = 5;
                } else if([last isEqualToString:@"4stars.gif"]) {
                    thread.threadRating = 4;
                } else if([last isEqualToString:@"3stars.gif"]) {
                    thread.threadRating = 3;
                } else if([last isEqualToString:@"2stars.gif"]) {
                    thread.threadRating = 2;
                } else if([last isEqualToString:@"1stars.gif"]) {
                    thread.threadRating = 1;
                } else if([last isEqualToString:@"0stars.gif"]) {
                    thread.threadRating = 0;
                }
            }
            
            TFHppleElement *date = [thread_base searchForSingle:@"//td[@class='lastpost']//div[@class='date']"];
            TFHppleElement *last_author = [thread_base searchForSingle:@"//td[@class='lastpost']//a[@class='author']"];
            
            if(date != nil && last_author != nil) {
                thread.lastPostAuthorName = [NSString stringWithFormat:@"%@", [last_author content]];
                
                static NSDateFormatter *df = nil;
                if(df == nil) {
                    df = [[NSDateFormatter alloc] init];
                    [df setTimeZone:[NSTimeZone localTimeZone]];
                    [df setDateFormat:@"HH:mm MMM d, yyyy"];
                }
                
                NSDate *myDate = [df dateFromString:[date content]];
                if(myDate != nil) {
                    thread.lastPostDate = myDate;
                }
            }
            
            [parsed_threads addObject:thread];
            
        }
    }

    return parsed_threads;
}

+(NSString *)getAdHTMLFromData : (TFHpple *)hpple
{
    NSArray *raws = [hpple rawSearch:@"//div[@id='ad_banner_user']/a"];
    if([raws count] == 0) {
        return @"";
    }
    
    return [NSString stringWithFormat:@"<div class='ad'>%@</div>", [raws objectAtIndex:0]];
}

+(int)getNewPostNumFromURL : (NSURL *)url
{
    NSString *frag = [url fragment];
    if(frag != nil) {
        NSRange r = [frag rangeOfString:@"pti"];
        if(r.location == 0) {
            NSString *new_post = [frag stringByReplacingOccurrencesOfString:@"pti" withString:@""];
            return [new_post intValue];
        }
    }
    return 0;
}

@end
