//
//  NSURL+Awful.m
//  Awful
//
//  Created by Nolan Waite on 2012-12-19.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "NSURL+Awful.h"

@implementation NSURL (Awful)

- (NSURL *)awfulURL
{
    if ([[self scheme] compare:@"awful" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
        return self;
    }
    if ([[self host] compare:@"forums.somethingawful.com"
                     options:NSCaseInsensitiveSearch] != NSOrderedSame) {
        return nil;
    }
    
    NSDictionary *query = [self queryDictionary];
    // Thread or post.
    if ([[self path] compare:@"/showthread.php" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
        // Link to specific post.
        if ([query[@"goto"] isEqual:@"post"] && query[@"postid"]) {
            return [NSURL URLWithString:[NSString stringWithFormat:
                    @"awful://posts/%@", query[@"postid"]]];
        }
        // Link to specific post.
        else if ([[self fragment] hasPrefix:@"post"] && [[self fragment] length] > 4) {
            return [NSURL URLWithString:[NSString stringWithFormat:
                    @"awful://posts/%@", [[self fragment] substringFromIndex:4]]];
        }
        // Link to page on specific thread.
        else if (query[@"threadid"] && query[@"pagenumber"]) {
            return [NSURL URLWithString:[NSString stringWithFormat:
                    @"awful://threads/%@/pages/%@", query[@"threadid"], query[@"pagenumber"]]];
        }
        // Link to specific thread.
        else if (query[@"threadid"]) {
            return [NSURL URLWithString:[NSString stringWithFormat:
                    @"awful://threads/%@/pages/1", query[@"threadid"]]];
        }
    }
    // Forum.
    else if ([[self path] compare:@"/forumdisplay.php"
                          options:NSCaseInsensitiveSearch] == NSOrderedSame) {
        if (query[@"forumid"]) {
            return [NSURL URLWithString:[NSString stringWithFormat:
                    @"awful://forums/%@", query[@"forumid"]]];
        }
    }
    return nil;
}

@end
