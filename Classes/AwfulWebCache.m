//
//  AwfulWebCache.m
//  Awful
//
//  Created by Sean Berry on 7/27/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulWebCache.h"
#import "AwfulUtil.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "AwfulConfig.h"

@implementation AwfulWebCache

- (NSCachedURLResponse*)cachedResponseForRequest:(NSURLRequest *)request
{
    NSCachedURLResponse *old = [super cachedResponseForRequest:request];
    if(old != nil) {
        return old;
    }
        
    if(!([self smilieCheck:request] || [self cssCheck:request] || [AwfulWebCache isURLAllowed:request])) {
        NSURL *url = [request URL];
        NSURLResponse *empty_response =
              [[NSURLResponse alloc] initWithURL:url
                                        MIMEType:@"text/plain"
                           expectedContentLength:1
                                textEncodingName:nil];

        NSCachedURLResponse *empty_cached_response =
              [[NSCachedURLResponse alloc] initWithResponse:empty_response
                             data:[NSData dataWithBytes:" " length:1]];

        [super storeCachedResponse:empty_cached_response forRequest:request];

        [empty_cached_response release];
        [empty_response release];
    }
    
    return [super cachedResponseForRequest:request];
}

+(BOOL)isURLAllowed : (NSURLRequest *)request
{
    NSURL *url = [request URL];
    
    NSArray *host_whitelist = [AwfulWebCache newThumbnailWhitelist];
    NSString *host = [url host];
    for(NSString *h in host_whitelist) {
        if([host isEqualToString:h]) {
            [host_whitelist release];
            return YES;
        }
    }
    [host_whitelist release];
    
    if([AwfulConfig imagesInline]) {
        return YES;
    }
    
    NSString *last = [url lastPathComponent];
    NSArray *not_ok = [[NSArray alloc] initWithObjects:@".gif", @".jpg", @".jpeg", @".png", @".js", @".css", nil];
    for(NSString *banned in not_ok) {
        NSRange r = [last rangeOfString:banned];
        if(r.location != NSNotFound) {
            [not_ok release];
            return NO;
        }
    }
    [not_ok release];
    return YES;
}

+(NSArray *)newThumbnailWhitelist
{
    NSArray *whitelist = [[NSArray alloc] initWithObjects:@"fi.somethingawful.com", @"i.somethingawful.com", @"forumimages.somethingawful.com", nil];
    return whitelist;
}

-(BOOL)smilieCheck : (NSURLRequest *)request
{
    NSURL *url = [request URL];
    BOOL special = [[url lastPathComponent] isEqualToString:@"notloaded.png"];
    special = special || [[url lastPathComponent] isEqualToString:@"star_admin.gif"];
    special = special || [[url lastPathComponent] isEqualToString:@"star_moderator.gif"];
    if([[url pathExtension] isEqualToString:@"gif"] || [[url pathExtension] isEqualToString:@"png"] || special) {
    
        // is it a smilie?
        
        FMDatabase *db = [AwfulUtil getDB];
        [db open];
        int exists = [db intForQuery:@"SELECT COUNT(*) FROM smilies WHERE filename = ?", [url lastPathComponent]];
        
        [db close];
        if(exists > 0 || special) {
            NSData *im_data = [[NSData alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:[url lastPathComponent] ofType:nil]];
            
            NSURLResponse *smilie_response =
              [[NSURLResponse alloc] initWithURL:url
                                        MIMEType:[@"image/" stringByAppendingString:[url pathExtension]]
                           expectedContentLength:[im_data length]
                                textEncodingName:nil];

            NSCachedURLResponse *cached_smilie_response =
                  [[NSCachedURLResponse alloc] initWithResponse:smilie_response
                                 data:im_data];

            [super storeCachedResponse:cached_smilie_response forRequest:request];
            [im_data release];
            [cached_smilie_response release];
            [smilie_response release];
            
            return YES;
        }
    }
    return NO;
}

-(BOOL)cssCheck : (NSURLRequest *)request
{
    NSURL *url = [request URL];
    if([[url lastPathComponent] isEqualToString:@"post.css"]) {
        NSData *css_data = [[NSData alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"post" ofType:@"css"]];
        
        NSURLResponse *css_response =
          [[NSURLResponse alloc] initWithURL:url
                                    MIMEType:@"text/css"
                       expectedContentLength:[css_data length]
                            textEncodingName:nil];

        NSCachedURLResponse *cached_css_response =
              [[NSCachedURLResponse alloc] initWithResponse:css_response
                             data:css_data];

        [super storeCachedResponse:cached_css_response forRequest:request];
        
        [css_data release];

        [cached_css_response release];
        [css_response release];
        return YES;
    }
    return NO;
}

@end
