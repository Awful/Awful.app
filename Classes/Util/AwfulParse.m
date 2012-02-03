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
    NSString *avatar_str;
    
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
        
    return html;
}

+(NSString *)getPostActionHTML
{
    return @"<img class='postaction' src='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFYAAABMCAYAAAD3G0AKAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAyBpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBhY2tldCBiZWdpbj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+IDx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuMC1jMDYwIDYxLjEzNDc3NywgMjAxMC8wMi8xMi0xNzozMjowMCAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvIiB4bWxuczp4bXBNTT0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL21tLyIgeG1sbnM6c3RSZWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9zVHlwZS9SZXNvdXJjZVJlZiMiIHhtcDpDcmVhdG9yVG9vbD0iQWRvYmUgUGhvdG9zaG9wIENTNSBXaW5kb3dzIiB4bXBNTTpJbnN0YW5jZUlEPSJ4bXAuaWlkOjAxRkZBRTk2QTZDMDExRTA4OTk3QjUzMDNGM0VGNTQ3IiB4bXBNTTpEb2N1bWVudElEPSJ4bXAuZGlkOjAxRkZBRTk3QTZDMDExRTA4OTk3QjUzMDNGM0VGNTQ3Ij4gPHhtcE1NOkRlcml2ZWRGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6MDFGRkFFOTRBNkMwMTFFMDg5OTdCNTMwM0YzRUY1NDciIHN0UmVmOmRvY3VtZW50SUQ9InhtcC5kaWQ6MDFGRkFFOTVBNkMwMTFFMDg5OTdCNTMwM0YzRUY1NDciLz4gPC9yZGY6RGVzY3JpcHRpb24+IDwvcmRmOlJERj4gPC94OnhtcG1ldGE+IDw/eHBhY2tldCBlbmQ9InIiPz5ksT9ZAAAETElEQVR42uycz2vUQBTHZ7JZd9utVYvSHjxYsYKngnvx2Jugf29PIigi9tJDLwUVBH+BhW5X7Wq7bHfjvHSCZZuZZLN5703SefDYtilJ5rPfvB+TSULx+FlXeCvdAo8Ax8LkBzkeeRolWBQopFJ6xfpQ4MF682ApkleqqSAcyUb86e1ihoqEjMbxZyHFeqgZgptHsTHg3e3d+Nfu86st1N1toTl0swTnY6xPXh6sNw/Wg/VgvXmwRJ2XbwQKNQqX/+YVSzVX4BVbQLI+FJCFAg07RDtmRW71RI1mLZLXI+VLTAz/KN/HV6zAVazBAOoDJrCf6py8jhiv+p/uJC/LDHlB6zOCPSRJXppZhmJRwI6VN6hzFJ1io6kGQaZ4ZQaY+wstn6uBWSCIyaJckmwhSBq5cTQIHIrFSZqmuYKIZ66gVxuwDjUIYL+VnxHW0BO0q8TCjCPGRsRlV1/DJYqx02CB/rTXIxzghQELM65pwyNixQo8xboTY6k7sB6qYg1lARdYSGAwr9hEPg40Bb9owfIlL8pw0Mfoy2dMXtRcScDiJkkLM857XhSVAfKX5+Y9r37lwVpaWk6wA+VD5S2k/UN3d0wO1oHkha3aHm7iMjGTrJ1XYoeVDjW5Oi+edQXYihVcoYB7JUyv0op1eCXMifJT5e2S9ztCT1y5kxdPjMUqiWhmz1KZSSeqAiwIRLNnZmYuLIqrtmINYdcFsNVVbK6qQLKtQYbu66/yxZL3RwA2cLbzwlAY4W0fvnUFayLfss0yLxfYV54VjTBX8YMgFKT8U9gS4mx4/lCu2b4pPzBsgzWpT5QvEKp/TXtWuHhh2b6q/O4ljhcf0gY2RSdh5NKt8x3YDU5gxbANivRXumB3xeB2zWtLA7GSBnVacDGbwuVWeE3Im6vmA5wORDSIw+M9Yb6/BIsl3ijfEvxP6cBs11tLHL6hx6LAKb7tAovPZZ7OK8sXricHh93dV94xHA5CxY4DaoX3Lnw3bOvoMch4TDC2IkzKahDk8u3zSc/TQZI03uv+f9o+65PfZIIKzx98NGxr63MPACqMad6JmSC7dMh2uXxHiFYn+aIeCvNtbdvgMA2+1D3DtqY+5xDGEI9lDhb5JmFm8DgWtxaTE92IGs3Qcjl+JYR6aApD+hw34nNW5x6PYU4O/2WK99JIKLU+yPFoYqhGtnRZg2nHuqwapkANtFI7GAfGzNJwwutqAGnBe6IrBcxFyENdVqVBhXNax4IaKzaa4cmYWd5ilPPJRGgcniI0EFD6vczT3s7yZGLyFiNuxeaxE4QGIqtWJTEXHqtPGoiyFgfbatUrBTZpIN6J+dcBcJVzzoIF+6LVhlGrXmmwQqttv6Did1waiIuvLtnT6uOK0bUFK7T6DpiqilqDzdNAjDTUExcH4PJbjBJwA6bOrbZgL17qw4KhwoO12LHu+ccFkxuLhaIa1tNt6poo+4U5SPZPgAEAV87x0PpJeFMAAAAASUVORK5CYII=' />";
}

+(NSString *)getModImgHTML
{
    return @"<img src='data:image/gif;base64,iVBORw0KGgoAAAANSUhEUgAAAA4AAAANCAYAAACZ3F9/AAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAyJpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBhY2tldCBiZWdpbj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+IDx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuMC1jMDYwIDYxLjEzNDc3NywgMjAxMC8wMi8xMi0xNzozMjowMCAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvIiB4bWxuczp4bXBNTT0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL21tLyIgeG1sbnM6c3RSZWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9zVHlwZS9SZXNvdXJjZVJlZiMiIHhtcDpDcmVhdG9yVG9vbD0iQWRvYmUgUGhvdG9zaG9wIENTNSBNYWNpbnRvc2giIHhtcE1NOkluc3RhbmNlSUQ9InhtcC5paWQ6ODREMjNDREYwQkUyMTFFMEFCOTFFMkI4RjAwQ0Q1NkYiIHhtcE1NOkRvY3VtZW50SUQ9InhtcC5kaWQ6ODREMjNDRTAwQkUyMTFFMEFCOTFFMkI4RjAwQ0Q1NkYiPiA8eG1wTU06RGVyaXZlZEZyb20gc3RSZWY6aW5zdGFuY2VJRD0ieG1wLmlpZDo4NEQyM0NERDBCRTIxMUUwQUI5MUUyQjhGMDBDRDU2RiIgc3RSZWY6ZG9jdW1lbnRJRD0ieG1wLmRpZDo4NEQyM0NERTBCRTIxMUUwQUI5MUUyQjhGMDBDRDU2RiIvPiA8L3JkZjpEZXNjcmlwdGlvbj4gPC9yZGY6UkRGPiA8L3g6eG1wbWV0YT4gPD94cGFja2V0IGVuZD0iciI/PpAokVwAAAE7SURBVHjaYvj//z8DOgYCISDuxSYHV4ND43wGMQUQw4xojUDgyiCj+Z/BIR7EOYxLIxMDEmBkZOQBUjMZtOwZGNSsGBhUzGyAYlEMWAALVIMikAIpCGHQd1NkUDCEyIIMYGBYCpRPBtK7gXgT0LZrYD2gQGDgFSkCms7AoGTEwCAsy7Aw0YEhfv4BhPHPbjAwPLnOwHBhx18gzweoeQfIqWUMn990M/z8ysDAJwZWd/HxO1R3MTLBNEWDNIGFoAECcm4Xg3lwKdCpqJr+/2NgmJ0J07QSJowcOBcY3j7GDIVrB0HkdGRN6BofMXyBOhFkwMVdDAy/fwJVgMOPDcNApPiTZuAW+M+g5wLinAfiLiD+xmDqD+Kvw5kAgIAZiH+CUw0DAyfcMAaGOUB8DG/KAQI/HElQAl0MIMAA4HIEOndFux8AAAAASUVORK5CYII=' />";
}

+(NSString *)getAdminImgHTML
{
    return @"<img src='data:image/gif;base64,iVBORw0KGgoAAAANSUhEUgAAAA4AAAANCAYAAACZ3F9/AAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAyJpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBhY2tldCBiZWdpbj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+IDx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuMC1jMDYwIDYxLjEzNDc3NywgMjAxMC8wMi8xMi0xNzozMjowMCAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvIiB4bWxuczp4bXBNTT0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL21tLyIgeG1sbnM6c3RSZWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9zVHlwZS9SZXNvdXJjZVJlZiMiIHhtcDpDcmVhdG9yVG9vbD0iQWRvYmUgUGhvdG9zaG9wIENTNSBNYWNpbnRvc2giIHhtcE1NOkluc3RhbmNlSUQ9InhtcC5paWQ6ODREMjNDREIwQkUyMTFFMEFCOTFFMkI4RjAwQ0Q1NkYiIHhtcE1NOkRvY3VtZW50SUQ9InhtcC5kaWQ6ODREMjNDREMwQkUyMTFFMEFCOTFFMkI4RjAwQ0Q1NkYiPiA8eG1wTU06RGVyaXZlZEZyb20gc3RSZWY6aW5zdGFuY2VJRD0ieG1wLmlpZDo4NEQyM0NEOTBCRTIxMUUwQUI5MUUyQjhGMDBDRDU2RiIgc3RSZWY6ZG9jdW1lbnRJRD0ieG1wLmRpZDo4NEQyM0NEQTBCRTIxMUUwQUI5MUUyQjhGMDBDRDU2RiIvPiA8L3JkZjpEZXNjcmlwdGlvbj4gPC9yZGY6UkRGPiA8L3g6eG1wbWV0YT4gPD94cGFja2V0IGVuZD0iciI/PmE3J4AAAAE7SURBVHjaYvj//z8DOgYCISDuxSYHV4ND43wFBhYQw4xojUDgqsnA+j+egRvEOUyURiDgAeJ7GQw8/2cyCP03Y2ADCUZh08gCUs3IyKgIUgDEIW4MHIqGDGwgYQZ7Bg4QtRQonwykdwPxJqCma2A9oEAQYWAqMmNgZzACapBlYGZwWDiN4UB8FgMM3GD4zXAdiHcw/PgL5PoANe9gAjLK3jD86/7K8I9BjIEJrPDdxSsMyIAJaD5UUzRIE9hGqN9Azu0KZuAqdYM4Dw7+AXEmwzuYppUIwxDgwmOGPwzo4CDDDxA1HVkTusZH78DmMzA8ZvjLsAuo4ScDKPRAwQANLWSAFBXSAgxM/10YOECc80DcBcTf/Bk4Qfx1OOMRCJiB+Cco1QAxJ8wwIJ4DxMcIJQA/HElQAl0MIMAAlOkdzj3Sg58AAAAASUVORK5CYII=' />";
}

+(NSMutableArray *)newPostsFromThread : (TFHpple *)hpple isFYAD : (BOOL)is_fyad
{
    NSArray *post_strings = PerformRawHTMLXPathQuery(hpple.data, @"//table[@class='post']|//table[@class='post ignored']");
    
    NSMutableArray *parsed_posts = [[NSMutableArray alloc] init];
    NSString *username = getUsername();
    
    BOOL show_avatars = [AwfulConfig showAvatars];
    
    for(NSString *post_html in post_strings) {
            
        @autoreleasepool {
    
            TFHpple *post_base = [[TFHpple alloc] initWithHTMLData:[post_html dataUsingEncoding:NSUTF8StringEncoding]];
            
            AwfulPost *post = [[AwfulPost alloc] init];
            post.rawContent = post_html;
            
            NSString *username_search = @"//dt[@class='author']|//dt[@class='author op']|//dt[@class='author role-mod']|//dt[@class='author role-admin']|//dt[@class='author role-mod op']|//dt[@class='author role-admin op']";
            
            TFHppleElement *author = [post_base searchForSingle:username_search];
            if(author != nil) {
                post.posterName = [author content];
                if([[author objectForKey:@"class"] isEqualToString:@"author op"] || [[author objectForKey:@"class"] isEqualToString:@"author role-admin op"] || [[author objectForKey:@"class"] isEqualToString:@"author role-mod op"]) {
                    post.isOP = YES;
                } else {
                    post.isOP = NO;
                }
                
                TFHppleElement *mod = [post_base searchForSingle:@"//dt[@class='author role-mod']|//dt[@class='author role-mod op']"];
                if(mod != nil) {
                    post.posterType = AwfulUserTypeMod;
                }
                
                TFHppleElement *admin = [post_base searchForSingle:@"//dt[@class='author role-admin']|//dt[@class='author role-admin op']"];
                if(admin != nil) {
                    post.posterType = AwfulUserTypeAdmin;
                }
                
                if([post.posterName isEqualToString:username]) {
                    post.canEdit = YES;
                }
            }
            
            TFHppleElement *post_id = [post_base searchForSingle:@"//table[@class='post']|//table[@class='post ignored']"];
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
                post.markSeenLink = [seen_link objectForKey:@"href"];
            }
            
            TFHppleElement *avatar = [post_base searchForSingle:@"//dd[@class='title']//img"];
            if(avatar != nil && show_avatars) {
                post.avatarURL = [NSURL URLWithString:[avatar objectForKey:@"src"]];
            }
            
            TFHppleElement *edited = [post_base searchForSingle:@"//p[@class='editedby']/span"];
            if(edited != nil) {
                post.editedStr = [[edited content] stringByReplacingOccurrencesOfString:@"fucked around with this message" withString:@"edited"];
            }
            
            NSString *body_search_str = nil;
            if(is_fyad) {
                body_search_str = @"//div[@class='complete_shit funbox']";
            } else {
                body_search_str = @"//td[@class='postbody']";
            }
            
            NSArray *body_strings = [post_base rawSearch:body_search_str];
            
            if([body_strings count] == 1) {
                NSString *post_body = [body_strings objectAtIndex:0];
                            
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
                
                @autoreleasepool {
                    post.formattedHTML = [AwfulParse constructPostHTML:post withBody:post_body alt:alt];
                }
            }
            
            [parsed_posts addObject:post];
            
        
        }
    }

    return parsed_posts;
}

+(NSString *)constructPageHTMLFromPosts : (NSMutableArray *)posts pagesLeft : (int)pages_left numOldPosts : (int)num_above adHTML : (NSString *)adHTML
{
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
    
    return html;
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
            }
            
            [parsed_threads addObject:thread];
            
        
        }
    }

    return parsed_threads;
}

+(AwfulPageCount *)newPageCount : (TFHpple *)hpple
{
    
    
    return pages;
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
