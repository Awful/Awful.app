//
//  PostContext.m
//  Awful
//
//  Created by Nolan Waite on 12-04-12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "PostContext.h"
#import "AwfulConfig.h"
#import "AwfulPost.h"
#import "TFHpple.h"
#import "TFHppleElement.h"

@implementation PostContext

static NSString *AwfulifiedPostBody(NSString *body);

- (id)initWithPost:(AwfulPost *)post
{
    self = [super init];
    if (self)
    {
        _postID = post.postID;
        _isOP = post.isOP;
        _avatarURL = [AwfulConfig showAvatars] ? [post.avatarURL absoluteString] : nil;
        _isMod = post.posterType == AwfulUserTypeMod;
        _isAdmin = post.posterType == AwfulUserTypeAdmin;
        _posterName = post.posterName;
        _postDate = post.postDate;
        _altCSSClass = post.altCSSClass;
        _postBody = AwfulifiedPostBody(post.postBody);
    }
    return self;
}

static NSString *AwfulifiedPostBody(NSString *body)
{
    TFHpple *base = [[TFHpple alloc] initWithHTMLData:[body dataUsingEncoding:NSUTF8StringEncoding]];
    NSMutableString *awfulified = [body mutableCopy];
    
    // Replace images with links if so desired.
    if (![AwfulConfig showImages]) {
        NSArray *objects = [base search:@"//img"];
        NSArray *object_strs = [base rawSearch:@"//img"];
        for(int i = 0; i < [objects count]; i++) {
            TFHppleElement *el = [objects objectAtIndex:i];
            NSString *src = [el objectForKey:@"src"];
            NSString *reformed = [NSString stringWithFormat:@"<a href='%@'>IMG LINK</a>", src];
            [awfulified replaceOccurrencesOfString:[object_strs objectAtIndex:i]
                                        withString:reformed
                                           options:0
                                             range:NSMakeRange(0, awfulified.length)];
        }
    }
    
    // Replace embedded youtube/vimeo with links.
    NSArray *objects = [base search:@"//object/param[@name='movie']"];
    NSArray *object_strs = [base rawSearch:@"//object"];
    
    for (int i = 0; i < [objects count]; i++) {
        TFHppleElement *el = [objects objectAtIndex:i];
        NSRange r = [[el objectForKey:@"value"] rangeOfString:@"youtube"];
        if (r.location != NSNotFound) {
            NSURL *youtube_url = [NSURL URLWithString:[el objectForKey:@"value"]];
            NSString *youtube_str = [NSString stringWithFormat:@"http://www.youtube.com/watch?v=%@", [youtube_url lastPathComponent]];
            NSString *reformed_youtube = [NSString stringWithFormat:@"<a href='%@'>Embedded YouTube</a>", youtube_str];
            if (i < [object_strs count]) {
                [awfulified replaceOccurrencesOfString:[object_strs objectAtIndex:i]
                                            withString:reformed_youtube
                                               options:0
                                                 range:NSMakeRange(0, awfulified.length)];
            }
        } else {
            r = [[el objectForKey:@"value"] rangeOfString:@"vimeo"];
            if (r.location != NSNotFound) {
                NSRange clip = [[el objectForKey:@"value"] rangeOfString:@"clip_id="];
                NSRange and = [[el objectForKey:@"value"] rangeOfString:@"&"];
                NSRange clip_range;
                clip_range.location = clip.location + 8;
                clip_range.length = and.location - clip.location - 8;
                NSString *clip_id = [[el objectForKey:@"value"] substringWithRange:clip_range];
                NSString *reformed_vimeo = [NSString stringWithFormat:@"<a href='http://www.vimeo.com/m/#/%@'>Embedded Vimeo</a>", clip_id];
                [awfulified replaceOccurrencesOfString:[object_strs objectAtIndex:i]
                                            withString:reformed_vimeo
                                               options:0
                                                 range:NSMakeRange(0, awfulified.length)];
            }
        }
    }
    
    // TODO what's going on here?
    [awfulified replaceOccurrencesOfString:@"&#13;"
                                withString:@""
                                   options:0
                                     range:NSMakeRange(0, awfulified.length)];
    
    return awfulified;
}

@synthesize postID = _postID;
@synthesize isOP = _isOP;
@synthesize avatarURL = _avatarURL;
@synthesize isMod = _isMod;
@synthesize isAdmin = _isAdmin;
@synthesize posterName = _posterName;
@synthesize postDate = _postDate;
@synthesize altCSSClass = _altCSSClass;
@synthesize postBody = _postBody;

@end
