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
@synthesize modImageHTML = _modImageHTML;
@synthesize adminImageHTML = _adminImageHTML;
@synthesize postActionImageHTML = _postActionImageHTML;
@synthesize pageCSS = _pageCSS;
@synthesize avatarHTML = _avatarHTML;

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
    return @"<img class='postaction' src='data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAFYAAABMCAYAAAD3G0AKAAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAyBpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBhY2tldCBiZWdpbj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+IDx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuMC1jMDYwIDYxLjEzNDc3NywgMjAxMC8wMi8xMi0xNzozMjowMCAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvIiB4bWxuczp4bXBNTT0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL21tLyIgeG1sbnM6c3RSZWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9zVHlwZS9SZXNvdXJjZVJlZiMiIHhtcDpDcmVhdG9yVG9vbD0iQWRvYmUgUGhvdG9zaG9wIENTNSBXaW5kb3dzIiB4bXBNTTpJbnN0YW5jZUlEPSJ4bXAuaWlkOjAxRkZBRTk2QTZDMDExRTA4OTk3QjUzMDNGM0VGNTQ3IiB4bXBNTTpEb2N1bWVudElEPSJ4bXAuZGlkOjAxRkZBRTk3QTZDMDExRTA4OTk3QjUzMDNGM0VGNTQ3Ij4gPHhtcE1NOkRlcml2ZWRGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6MDFGRkFFOTRBNkMwMTFFMDg5OTdCNTMwM0YzRUY1NDciIHN0UmVmOmRvY3VtZW50SUQ9InhtcC5kaWQ6MDFGRkFFOTVBNkMwMTFFMDg5OTdCNTMwM0YzRUY1NDciLz4gPC9yZGY6RGVzY3JpcHRpb24+IDwvcmRmOlJERj4gPC94OnhtcG1ldGE+IDw/eHBhY2tldCBlbmQ9InIiPz5ksT9ZAAAETElEQVR42uycz2vUQBTHZ7JZd9utVYvSHjxYsYKngnvx2Jugf29PIigi9tJDLwUVBH+BhW5X7Wq7bHfjvHSCZZuZZLN5703SefDYtilJ5rPfvB+TSULx+FlXeCvdAo8Ax8LkBzkeeRolWBQopFJ6xfpQ4MF682ApkleqqSAcyUb86e1ihoqEjMbxZyHFeqgZgptHsTHg3e3d+Nfu86st1N1toTl0swTnY6xPXh6sNw/Wg/VgvXmwRJ2XbwQKNQqX/+YVSzVX4BVbQLI+FJCFAg07RDtmRW71RI1mLZLXI+VLTAz/KN/HV6zAVazBAOoDJrCf6py8jhiv+p/uJC/LDHlB6zOCPSRJXppZhmJRwI6VN6hzFJ1io6kGQaZ4ZQaY+wstn6uBWSCIyaJckmwhSBq5cTQIHIrFSZqmuYKIZ66gVxuwDjUIYL+VnxHW0BO0q8TCjCPGRsRlV1/DJYqx02CB/rTXIxzghQELM65pwyNixQo8xboTY6k7sB6qYg1lARdYSGAwr9hEPg40Bb9owfIlL8pw0Mfoy2dMXtRcScDiJkkLM857XhSVAfKX5+Y9r37lwVpaWk6wA+VD5S2k/UN3d0wO1oHkha3aHm7iMjGTrJ1XYoeVDjW5Oi+edQXYihVcoYB7JUyv0op1eCXMifJT5e2S9ztCT1y5kxdPjMUqiWhmz1KZSSeqAiwIRLNnZmYuLIqrtmINYdcFsNVVbK6qQLKtQYbu66/yxZL3RwA2cLbzwlAY4W0fvnUFayLfss0yLxfYV54VjTBX8YMgFKT8U9gS4mx4/lCu2b4pPzBsgzWpT5QvEKp/TXtWuHhh2b6q/O4ljhcf0gY2RSdh5NKt8x3YDU5gxbANivRXumB3xeB2zWtLA7GSBnVacDGbwuVWeE3Im6vmA5wORDSIw+M9Yb6/BIsl3ijfEvxP6cBs11tLHL6hx6LAKb7tAovPZZ7OK8sXricHh93dV94xHA5CxY4DaoX3Lnw3bOvoMch4TDC2IkzKahDk8u3zSc/TQZI03uv+f9o+65PfZIIKzx98NGxr63MPACqMad6JmSC7dMh2uXxHiFYn+aIeCvNtbdvgMA2+1D3DtqY+5xDGEI9lDhb5JmFm8DgWtxaTE92IGs3Qcjl+JYR6aApD+hw34nNW5x6PYU4O/2WK99JIKLU+yPFoYqhGtnRZg2nHuqwapkANtFI7GAfGzNJwwutqAGnBe6IrBcxFyENdVqVBhXNax4IaKzaa4cmYWd5ilPPJRGgcniI0EFD6vczT3s7yZGLyFiNuxeaxE4QGIqtWJTEXHqtPGoiyFgfbatUrBTZpIN6J+dcBcJVzzoIF+6LVhlGrXmmwQqttv6Did1waiIuvLtnT6uOK0bUFK7T6DpiqilqDzdNAjDTUExcH4PJbjBJwA6bOrbZgL17qw4KhwoO12LHu+ccFkxuLhaIa1tNt6poo+4U5SPZPgAEAV87x0PpJeFMAAAAASUVORK5CYII=' />";
}

-(NSString *)getModImageHTML
{
    return @"<img src='data:image/gif;base64,iVBORw0KGgoAAAANSUhEUgAAAA4AAAANCAYAAACZ3F9/AAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAyJpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBhY2tldCBiZWdpbj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+IDx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuMC1jMDYwIDYxLjEzNDc3NywgMjAxMC8wMi8xMi0xNzozMjowMCAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvIiB4bWxuczp4bXBNTT0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL21tLyIgeG1sbnM6c3RSZWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9zVHlwZS9SZXNvdXJjZVJlZiMiIHhtcDpDcmVhdG9yVG9vbD0iQWRvYmUgUGhvdG9zaG9wIENTNSBNYWNpbnRvc2giIHhtcE1NOkluc3RhbmNlSUQ9InhtcC5paWQ6ODREMjNDREYwQkUyMTFFMEFCOTFFMkI4RjAwQ0Q1NkYiIHhtcE1NOkRvY3VtZW50SUQ9InhtcC5kaWQ6ODREMjNDRTAwQkUyMTFFMEFCOTFFMkI4RjAwQ0Q1NkYiPiA8eG1wTU06RGVyaXZlZEZyb20gc3RSZWY6aW5zdGFuY2VJRD0ieG1wLmlpZDo4NEQyM0NERDBCRTIxMUUwQUI5MUUyQjhGMDBDRDU2RiIgc3RSZWY6ZG9jdW1lbnRJRD0ieG1wLmRpZDo4NEQyM0NERTBCRTIxMUUwQUI5MUUyQjhGMDBDRDU2RiIvPiA8L3JkZjpEZXNjcmlwdGlvbj4gPC9yZGY6UkRGPiA8L3g6eG1wbWV0YT4gPD94cGFja2V0IGVuZD0iciI/PpAokVwAAAE7SURBVHjaYvj//z8DOgYCISDuxSYHV4ND43wGMQUQw4xojUDgyiCj+Z/BIR7EOYxLIxMDEmBkZOQBUjMZtOwZGNSsGBhUzGyAYlEMWAALVIMikAIpCGHQd1NkUDCEyIIMYGBYCpRPBtK7gXgT0LZrYD2gQGDgFSkCms7AoGTEwCAsy7Aw0YEhfv4BhPHPbjAwPLnOwHBhx18gzweoeQfIqWUMn990M/z8ysDAJwZWd/HxO1R3MTLBNEWDNIGFoAECcm4Xg3lwKdCpqJr+/2NgmJ0J07QSJowcOBcY3j7GDIVrB0HkdGRN6BofMXyBOhFkwMVdDAy/fwJVgMOPDcNApPiTZuAW+M+g5wLinAfiLiD+xmDqD+Kvw5kAgIAZiH+CUw0DAyfcMAaGOUB8DG/KAQI/HElQAl0MIMAA4HIEOndFux8AAAAASUVORK5CYII=' />&nbsp;";
}

-(NSString *)getAdminImageHTML
{
    return @"<img src='data:image/gif;base64,iVBORw0KGgoAAAANSUhEUgAAAA4AAAANCAYAAACZ3F9/AAAAGXRFWHRTb2Z0d2FyZQBBZG9iZSBJbWFnZVJlYWR5ccllPAAAAyJpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBhY2tldCBiZWdpbj0i77u/IiBpZD0iVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkIj8+IDx4OnhtcG1ldGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1wdGs9IkFkb2JlIFhNUCBDb3JlIDUuMC1jMDYwIDYxLjEzNDc3NywgMjAxMC8wMi8xMi0xNzozMjowMCAgICAgICAgIj4gPHJkZjpSREYgeG1sbnM6cmRmPSJodHRwOi8vd3d3LnczLm9yZy8xOTk5LzAyLzIyLXJkZi1zeW50YXgtbnMjIj4gPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9IiIgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvIiB4bWxuczp4bXBNTT0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL21tLyIgeG1sbnM6c3RSZWY9Imh0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC9zVHlwZS9SZXNvdXJjZVJlZiMiIHhtcDpDcmVhdG9yVG9vbD0iQWRvYmUgUGhvdG9zaG9wIENTNSBNYWNpbnRvc2giIHhtcE1NOkluc3RhbmNlSUQ9InhtcC5paWQ6ODREMjNDREIwQkUyMTFFMEFCOTFFMkI4RjAwQ0Q1NkYiIHhtcE1NOkRvY3VtZW50SUQ9InhtcC5kaWQ6ODREMjNDREMwQkUyMTFFMEFCOTFFMkI4RjAwQ0Q1NkYiPiA8eG1wTU06RGVyaXZlZEZyb20gc3RSZWY6aW5zdGFuY2VJRD0ieG1wLmlpZDo4NEQyM0NEOTBCRTIxMUUwQUI5MUUyQjhGMDBDRDU2RiIgc3RSZWY6ZG9jdW1lbnRJRD0ieG1wLmRpZDo4NEQyM0NEQTBCRTIxMUUwQUI5MUUyQjhGMDBDRDU2RiIvPiA8L3JkZjpEZXNjcmlwdGlvbj4gPC9yZGY6UkRGPiA8L3g6eG1wbWV0YT4gPD94cGFja2V0IGVuZD0iciI/PmE3J4AAAAE7SURBVHjaYvj//z8DOgYCISDuxSYHV4ND43wFBhYQw4xojUDgqsnA+j+egRvEOUyURiDgAeJ7GQw8/2cyCP03Y2ADCUZh08gCUs3IyKgIUgDEIW4MHIqGDGwgYQZ7Bg4QtRQonwykdwPxJqCma2A9oEAQYWAqMmNgZzACapBlYGZwWDiN4UB8FgMM3GD4zXAdiHcw/PgL5PoANe9gAjLK3jD86/7K8I9BjIEJrPDdxSsMyIAJaD5UUzRIE9hGqN9Azu0KZuAqdYM4Dw7+AXEmwzuYppUIwxDgwmOGPwzo4CDDDxA1HVkTusZH78DmMzA8ZvjLsAuo4ScDKPRAwQANLWSAFBXSAgxM/10YOECc80DcBcTf/Bk4Qfx1OOMRCJiB+Cco1QAxJ8wwIJ4DxMcIJQA/HElQAl0MIMAAlOkdzj3Sg58AAAAASUVORK5CYII=' />&nbsp;";
}

-(NSString *)constructHTMLForPost : (AwfulPost *)post
{    
    NSString *parsed_post_body = post.postBody;
    
    if(![AwfulConfig showImages]) {
        parsed_post_body = [self parseOutImages:parsed_post_body];
    }
    parsed_post_body = [self parseEmbeddedVideos:parsed_post_body];
    parsed_post_body = [parsed_post_body stringByReplacingOccurrencesOfString:@"&#13;" withString:@""];
    
    self.avatarHTML = @"<td class='avatar_td'><img class='avatar_img' src='%AVATAR_URL%'/></td>";
    NSString *avatar = @"";
    if(post.avatarURL != nil) {
        avatar = [self.avatarHTML stringByReplacingOccurrencesOfString:@"%AVATAR_URL%" withString:[NSString stringWithFormat:@"%@", post.avatarURL]];
    }
    
    self.postHTML = @"<table id='%POST_ID%' class='userbox %OP%'><tr>%AVATAR_HTML%<td class='name_date_box'><span class='username %OP%'>%MOD_IMAGE%%ADMIN_IMAGE%%POSTER_NAME%</span><br/><span class='post_date'>Posted on %POST_DATE%</span></td><td></td><td class='quotebutton' onclick=tappedPost('%POST_ID%')>%POST_ACTION_IMAGE%</td></tr></table><div class='postbodymain %ALT_CLASS%'><div class='postbodysub'>%POST_BODY%</div></div>";
    
    self.postActionImageHTML = [self getPostActionImageHTML];
    self.modImageHTML = [self getModImageHTML];
    self.adminImageHTML = [self getAdminImageHTML];
    
    NSString *html = [self.postHTML stringByReplacingOccurrencesOfString:@"%POST_ID%" withString:post.postID];
    html = [html stringByReplacingOccurrencesOfString:@"%AVATAR_HTML%" withString:avatar];
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
    
    html = [html stringByReplacingOccurrencesOfString:@"%POST_ACTION_IMAGE%" withString:self.postActionImageHTML];
    
    /* prevent someone from naming themselves %POST_BODY% and messing up the format
    // the alternative was to let users put %POSTER_NAME% in their post body and have it sub in their name
    // this way only a guy named %POST_BODY% will have a slightly altered name */
    NSString *parsed_name = [post.posterName stringByReplacingOccurrencesOfString:@"%POST_BODY%" withString:@"POST_BODY"];
    html = [html stringByReplacingOccurrencesOfString:@"%POSTER_NAME%" withString:parsed_name];
    html = [html stringByReplacingOccurrencesOfString:@"%POST_BODY%" withString:parsed_post_body];
   
    return html;
}

-(NSString *)constructHTMLFromPageDataController : (AwfulPageDataController *)dataController
{
    NSString *combined = @"";
    for(AwfulPost *post in dataController.posts) {
        combined = [combined stringByAppendingString:[self constructHTMLForPost:post]];
    }
    
    NSString *pages_left_str = @"";
    NSUInteger pages_left = [dataController.pageCount getPagesLeft];
    if(pages_left > 1) {
        pages_left_str = [NSString stringWithFormat:@"%d pages left.", pages_left];
    } else if(pages_left == 1) {
        pages_left_str = @"1 page left.";
    } else {
        pages_left_str = @"End of the thread.";
    }
    
    
    //NSString *top = @"";
    /*
    if(num_above > 0) {
        NSString *above_str = @"";
        if(num_above == 1) {
            above_str = @"1 post above.";
        } else {
            above_str = [NSString stringWithFormat:@"%d posts above.", num_above];
        }
        top = [NSString stringWithFormat:@"<table class='olderposts'><tr><td onclick=tappedOlderPosts()>%@</td></tr></table>", above_str];
    }*/
    
    
    self.pageCSS = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"post" ofType:@"css"] encoding:NSUTF8StringEncoding error:nil];
    
    NSString *js = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"jquery" ofType:@"js"] encoding:NSUTF8StringEncoding error:nil];
    
    NSString *salr = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"salr" ofType:@"js"] encoding:NSUTF8StringEncoding error:nil];
    
    js = [js stringByAppendingString:salr];
        
    /*
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        width = @"width=80%, "; //700
    }*/
        
    // Fire off SALR
    NSString *salr_config = [SALR config];
    NSString *salrOpts = @"";
    if(![salr_config isEqualToString:@""]) {
        salrOpts = [NSString stringWithFormat:@"$(document).ready(function() { new SALR(%@); });", salr_config];
    }
    
    self.mainHTML = @"<html><head><meta name='viewport' content='width=device-width, minimum-scale=1.0, maximum-scale=1.0'><script type='text/javascript'>%JAVASCRIPT%</script><style type='text/css'>%CSS%</style></head><body><script type='text/javascript'>%SALR_EXECUTION%</script>%POSTS%<div class='ad'>%USER_AD%</div><div class='pagesleft' onclick=tappedBottom()>%PAGES_LEFT_MESSAGE%</div></body></html>";
    
    NSString *html = [self.mainHTML stringByReplacingOccurrencesOfString:@"%JAVASCRIPT%" withString:js];
    html = [html stringByReplacingOccurrencesOfString:@"%CSS%" withString:self.pageCSS];
    html = [html stringByReplacingOccurrencesOfString:@"%SALR_EXECUTION%" withString:salrOpts];
    html = [html stringByReplacingOccurrencesOfString:@"%PAGES_LEFT_MESSAGE%" withString:pages_left_str];
    html = [html stringByReplacingOccurrencesOfString:@"%USER_AD%" withString:dataController.userAd];
    html = [html stringByReplacingOccurrencesOfString:@"%POSTS%" withString:combined];
    
    return html;
}

@end


/* Notes. An element needs the %POST_ID% so it knows where to scroll down to for the 'newest post'.

 If the post if made by the OP, %OP% will insert the value, otherwise it will just leave it blank
 %AVATAR_URL% puts in the full url
 %MOD_IMAGE% inserts the html for ModImage, or nothing if they're not a mod. Same with %ADMIN_IMAGE%
 personal note, put in &nbsp; after the mod image to have a space in my template

%POSTER_NAME%, %POST_DATE%, %POST_BODY% are self explanatory
 
 %AVATAR_HTML% gets put in what you specified for the avatar html, unless they don't have an avatar, then nothing gets put in. Use %AVATAR_URL% inside your %AVATAR_HTML% specification.
 
tappedPost('%POST_ID') is some javascript that will call the post actions in the app.
 
for the _IMAGE ones... get to specify the image and the css class. it will convert it to base64 and proper <img thing when saving>
 
%POST_IMAGE% is the html that puts in the 
 
%ALT_CLASS% inserts either 'altcolor1', 'altcolor2', 'seen1', or 'seen2' depending on the post index (even/odd) and also if they're seen it or not. The default is blue for seen.
 
 %PAGES_LEFT_MESSAGE% is either 'x pages left.' '1 page left.' or 'End of the thread.'
 the tappedBottom() javascript triggers a 'next page' call if there are pages left

*/