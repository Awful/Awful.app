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
#import "AwfulNavController.h"
#import "AwfulConfig.h"

@implementation AwfulParse

+(NSString *)constructPostHTML : (AwfulPost *)post alt : (NSString *)alt
{
    NSString *avatar_str;
    
    if(post.avatar == nil) {
        avatar_str = @"";
    } else {
        avatar_str = [NSString stringWithFormat:@"<td id='avatar'><img class='avatar' src='%@'/></td>", post.avatar];
    }
    
    NSString *userbox_str = @"userbox";
    NSString *user_str = @"username";
    if(post.byOP) {
        user_str = @"username_op";
        userbox_str = @"userbox_op";
    }

    NSString *username_info = post.userName;
    if(post.isAdmin) {
        username_info = [NSString stringWithFormat:@"<img src='http://fi.somethingawful.com/star_admin.gif'/>&nbsp;%@", post.userName];
    } else if(post.isMod) {
        username_info = [NSString stringWithFormat:@"<img src='http://fi.somethingawful.com/star_moderator.gif'/>&nbsp;%@", post.userName];
    }
    
    NSString *name_avatar_box = [NSString stringWithFormat:@"<table id='%@'><tr>%@<td id='name_date_box'><span class='%@'>%@</span><br/><span class='post_date'>Posted on %@</span></td><td></td></tr></table>", userbox_str, avatar_str, user_str, username_info, post.postDate];
    
    NSString *css = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"post" ofType:@"css"] encoding:NSUTF8StringEncoding error:nil];

    NSString *post_body = [AwfulParse parseThumbnails:post.postBody];
    post_body = [AwfulParse parseYouTubes:post_body];

    NSString *html = [NSString stringWithFormat:@"<html><head><style type='text/css'>%@</style></head><body class='%@'>%@%@</body></html>", css, alt, name_avatar_box, post_body];
    html = [html stringByReplacingOccurrencesOfString:@"<td class=\"postbody\">" withString:@"<div class='postbody'>"];
    html = [html stringByReplacingOccurrencesOfString:@"</td>" withString:@"</div>"];
    //html = [html stringByReplacingOccurrencesOfString:@"<!-- EndContentMarker -->\n\n\n" withString:@""];
    
    return html;
}

+(NSMutableArray *)newPostsFromThread : (TFHpple *)hpple isFYAD : (BOOL)is_fyad
{
    NSArray *post_strings = PerformRawHTMLXPathQuery(hpple.data, @"//table[@class='post']");
    
    NSMutableArray *parsed_posts = [[NSMutableArray alloc] init];
    NSString *username = getUsername();
    
    BOOL show_avatars = [AwfulConfig showAvatars];

    for(NSString *post_html in post_strings) {
    
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
        TFHpple *post_base = [[TFHpple alloc] initWithHTMLData:[post_html dataUsingEncoding:NSUTF8StringEncoding]];
        
        AwfulPost *post = [[AwfulPost alloc] init];
        post.rawContent = post_html;
        
        NSString *username_search = @"//dt[@class='author']|//dt[@class='author op']|//dt[@class='author role-mod']|//dt[@class='author role-admin']|//dt[@class='author role-mod op']|//dt[@class='author role-admin op']";
        
        TFHppleElement *author = [post_base searchForSingle:username_search];
        if(author != nil) {
            post.userName = [author content];
            if([[author objectForKey:@"class"] isEqualToString:@"author op"] || [[author objectForKey:@"class"] isEqualToString:@"author role-admin op"] || [[author objectForKey:@"class"] isEqualToString:@"author role-mod op"]) {
                post.byOP = YES;
            } else {
                post.byOP = NO;
            }
            TFHppleElement *mod = [post_base searchForSingle:@"//dt[@class='author role-mod']|//dt[@class='author role-mod op']"];
            if(mod != nil) {
                post.isMod = YES;
            }
            
            TFHppleElement *admin = [post_base searchForSingle:@"//dt[@class='author role-admin']|//dt[@class='author role-admin op']"];
            if(admin != nil) {
                post.isAdmin = YES;
            }
            
            if([post.userName isEqualToString:username]) {
                post.canEdit = YES;
            }
        }
        
        TFHppleElement *post_id = [post_base searchForSingle:@"//table[@class='post']"];
        if(post_id != nil) {
            NSString *post_id_str = [post_id objectForKey:@"id"];
            post.postID = [post_id_str substringFromIndex:4];
        }
        
        TFHppleElement *post_date = [post_base searchForSingle:@"//td[@class='postdate']"];
        if(post_date != nil) {
            post.postDate = [post_date content];
        }
        
        TFHppleElement *seen_link = [post_base searchForSingle:@"//td[@class='postdate']//a[@title='Mark thread seen up to this post']"];
        if(seen_link != nil) {
            post.seenLink = [seen_link objectForKey:@"href"];
        }
        
        TFHppleElement *avatar = [post_base searchForSingle:@"//dd[@class='title']//img"];
        if(avatar != nil && show_avatars) {
            post.avatar = [avatar objectForKey:@"src"];
        }
        
        TFHppleElement *edited = [post_base searchForSingle:@"//p[@class='editedby']/span"];
        if(edited != nil) {
            post.edited = [[edited content] stringByReplacingOccurrencesOfString:@"fucked around with this message" withString:@"edited"];
        }
        
        NSString *body_search_str = nil;
        if(is_fyad) {
            body_search_str = @"//div[@class='complete_shit funbox']";
        } else {
            body_search_str = @"//td[@class='postbody']";
        }
        
        NSArray *body_strings = [post_base rawSearch:body_search_str];
        
        if([body_strings count] == 1) {
            post.postBody = [body_strings objectAtIndex:0];
                        
            TFHppleElement *seen = [post_base searchForSingle:@"//tr[@class='seen1']|//tr[@class='seen2']"];
            
            NSString *alt;
            if([post_strings indexOfObject:post_html] % 2 == 0) {
                if(seen == nil) {
                    alt = @"altcolor2";                
                } else {
                    alt = @"seen2";
                }
            } else {
                if(seen == nil) {
                    alt = @"altcolor1";
                } else {
                    alt = @"seen1";
                }
            }
            
            NSAutoreleasePool *body_pool = [[NSAutoreleasePool alloc] init];
            post.content = [AwfulParse constructPostHTML:post alt:alt];
            [body_pool release];
        }
        
        [parsed_posts addObject:post];
        
        [post release];
        [post_base release];
        
        [pool release];
    }

    return parsed_posts;
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
    [base release];
    
    return parsed;
}

+(NSString *)parseThumbnails : (NSString *)body_html
{
    TFHpple *base = [[TFHpple alloc] initWithHTMLData:[body_html dataUsingEncoding:NSUTF8StringEncoding]];
    NSString *parsed = body_html;
    
    NSArray *link_images = [base search:@"//a/img"];
    NSMutableArray *link_images_hrefs = [[NSMutableArray alloc] init];
    
    for(TFHppleElement *link_image in link_images) {
        [link_images_hrefs addObject:[link_image objectForKey:@"src"]];
    }
    
    NSArray *images = [base search:@"//img"];
    NSArray *image_strs = [base rawSearch:@"//img"];
    
    NSString *replaced_src;
    NSString *reformed_img;
    
    int non_forum_images = 0;
    
    for(int i = 0; i < [images count]; i++) {    
        TFHppleElement *image = [images objectAtIndex:i];
        NSString *src = [image objectForKey:@"src"];
        NSURL *url = [NSURL URLWithString:src];
        NSString *host = [url host];
        
        BOOL thumbnail_it = NO;
        if(![host isEqualToString:@"i.somethingawful.com"] && ![host isEqualToString:@"fi.somethingawful.com"]) {
            non_forum_images++;
            thumbnail_it = YES;
            
            if([AwfulConfig imagesInline]) {
                thumbnail_it = NO;
            }
            
            if(non_forum_images > 4) {
                thumbnail_it = YES;
            }
        }
        
        NSRange attach;
        attach = [src rangeOfString:@"attachment.php?"];
        if(attach.location == 0) {
            src = [NSString stringWithFormat:@"http://forums.somethingawful.com/%@", src];
        }

        if(thumbnail_it) {
            replaced_src = @"http://www.seaneseor.com/notloaded.png";
            
            BOOL already_link = NO;
            for(NSString *im in link_images_hrefs) {
                if([im isEqualToString:src]) {
                    already_link = YES;
                }
            }
            if(already_link) {
                reformed_img = [NSString stringWithFormat:@"<img height='50' width='50' src='%@' border=0/>", replaced_src];
            } else {
                reformed_img = [NSString stringWithFormat:@"<a href='%@'><img height='50' width='50' src='%@' border=0/></a>&nbsp;", src, replaced_src];
            }
            
            if(i < [image_strs count]) {
                parsed = [parsed stringByReplacingOccurrencesOfString:[image_strs objectAtIndex:i] withString:reformed_img];
            }
        } else if(![host isEqualToString:@"i.somethingawful.com"] && ![host isEqualToString:@"fi.somethingawful.com"]) {
            // take out linkage
            //reformed_img = [NSString stringWithFormat:@"<a href='%@'><img src='%@' border=0/></a>", src, src];
            reformed_img = [NSString stringWithFormat:@"<img src='%@' border=0/>", src];
            if(i < [image_strs count]) {
                parsed = [parsed stringByReplacingOccurrencesOfString:[image_strs objectAtIndex:i] withString:reformed_img];
            }
        }
    }
    
    [link_images_hrefs release];
    [base release];
    
    return parsed;
}

+(NSMutableArray *)newThreadsFromForum : (TFHpple *)hpple
{
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
    
        NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
        TFHpple *thread_base = [[TFHpple alloc] initWithHTMLData:[thread_html dataUsingEncoding:NSUTF8StringEncoding]];
        
        AwfulThread *thread = [[AwfulThread alloc] init];
        // i can't get the userid easily so scratch that
        
        TFHppleElement *title = [thread_base searchForSingle:@"//a[@class='thread_title']"];
        if(title != nil) {
            thread.threadTitle = [title content];
        }
        
        TFHppleElement *sticky = [thread_base searchForSingle:@"//td[@class='title title_sticky']"];
        if(sticky != nil) {
            thread.isStickied = YES;
        }
        
        TFHppleElement *icon = [thread_base searchForSingle:@"//td[@class='icon']/img"];
        if(icon != nil) {
            NSString *icon_str = [icon objectForKey:@"src"];
            thread.threadIcon = icon_str;
        }
        
        TFHppleElement *author = [thread_base searchForSingle:@"//td[@class='author']/a"];
        if(author != nil) {
            thread.threadAuthor = [author content];
        }
        
        TFHppleElement *tid = [thread_base searchForSingle:big_str];
        if(tid != nil) {
            NSString *tid_str = [tid objectForKey:@"id"];
            if(tid_str == nil) {
                // announcements don't have thread_ids, they get linked to announcement.php
                // gonna disregard announcements for now
                [thread release];
                [thread_base release];
                continue;
            } else {
                thread.threadID = [tid_str substringFromIndex:6];
            }
        }
        
        TFHppleElement *seen = [thread_base searchForSingle:seen_str];
        if(seen != nil) {
            thread.alreadyRead = YES;
        }
        
        TFHppleElement *locked = [thread_base searchForSingle:closed_str];
        if(locked != nil) {
            thread.isLocked = YES;
        }
        
        TFHppleElement *cat_zero = [thread_base searchForSingle:category_zero];
        if(cat_zero != nil) {
            thread.category = 0;
        }
        
        TFHppleElement *cat_one = [thread_base searchForSingle:category_one];
        if(cat_one != nil) {
            thread.category = 1;
        }
        
        TFHppleElement *cat_two = [thread_base searchForSingle:category_two];
        if(cat_two != nil) {
            thread.category = 2;
        }
        
        TFHppleElement *unread = [thread_base searchForSingle:@"//a[@class='count']/b"];
        if(unread != nil) {
            NSString *unread_str = [unread content];
            thread.numUnreadPosts = [unread_str intValue];
        } else {
            unread = [thread_base searchForSingle:@"//a[@class='x']"];
            if(unread != nil) {
                // they've read it all
                thread.numUnreadPosts = 0;
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
            if([last isEqualToString:@"4stars.gif"] || [last isEqualToString:@"5stars.gif"]) {
                thread.threadRating = RATED_GOLD;
            } else if([last isEqualToString:@"3stars.gif"]) {
                thread.threadRating = RATED_NOTHING;
            } else if([last isEqualToString:@"2stars.gif"] || [last isEqualToString:@"1stars.gif"] || [last isEqualToString:@"0stars.gif"]) {
                thread.threadRating = RATED_SHIT;
            }
        }
        
        TFHppleElement *date = [thread_base searchForSingle:@"//td[@class='lastpost']//div[@class='date']"];
        TFHppleElement *last_author = [thread_base searchForSingle:@"//td[@class='lastpost']//a[@class='author']"];
        
        if(date != nil && last_author != nil) {
            thread.killedBy = [NSString stringWithFormat:@"%@", [last_author content]];
        }
        
        [parsed_threads addObject:thread];
        
        [thread release];
        [thread_base release];
        
        [pool release];
    }

    return parsed_threads;
}

+(PageManager *)newPageManager : (TFHpple *)hpple
{
    PageManager *pages = [[PageManager alloc] init];
    
    NSArray *strings = PerformRawHTMLXPathQuery(hpple.data, @"//div[@class='pages top']");
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
            pages.total = [total_pages_str intValue];
            
            TFHpple *base = [[TFHpple alloc] initWithHTMLData:[page_info dataUsingEncoding:NSUTF8StringEncoding]];
            TFHppleElement *curpage = [base searchForSingle:@"//span[@class='curpage']"];
            if(curpage != nil) {
                pages.current = [[curpage content] intValue];
            }
            [base release];
        } else {
            pages.total = 1;
            pages.current = 1;
        }
    }
    
    return pages;
}

+(NSString *)getAdHTMLFromData : (TFHpple *)hpple
{
    NSArray *raws = [hpple rawSearch:@"//div[@id='ad_banner_user']/a"];
    if([raws count] == 0) {
        return nil;
    }
    
    NSMutableString *web_str = [[NSMutableString alloc] initWithFormat:@"<body style='margin:0px;padding:0px;'>%@</body>", [raws objectAtIndex:0]];
    [web_str replaceOccurrencesOfString:@"width=\"468\"" withString:@"width=\"100%\"" options:0 range:NSMakeRange(0, [web_str length])];
    [web_str replaceOccurrencesOfString:@"height=\"60\"" withString:@"height=\"100%\"" options:0 range:NSMakeRange(0, [web_str length])];
    
    return [web_str autorelease];
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
