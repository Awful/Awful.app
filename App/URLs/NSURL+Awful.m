//  NSURL+Awful.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "NSURL+Awful.h"
@import AwfulCore;

@implementation NSURL (Awful)

- (NSURL *)awfulURL
{
	if (self.scheme == nil) {
		return nil;
	}
    if ([self.scheme caseInsensitiveCompare:@"awful"] == NSOrderedSame) {
        return self;
    }
    if (   [self.host caseInsensitiveCompare:@"forums.somethingawful.com"] != NSOrderedSame
        && [self.host caseInsensitiveCompare:@"archives.somethingawful.com"] != NSOrderedSame
        && [self.host caseInsensitiveCompare:[AwfulForumsClient client].baseURL.host] != NSOrderedSame) {
        return nil;
    }
    
    NSDictionary *query = self.awful_queryDictionary;
    
    // Thread or post.
    if ([self.path caseInsensitiveCompare:@"/showthread.php"] == NSOrderedSame) {
        
        // Link to specific post.
        if (([query[@"goto"] isEqual:@"post"] || [query[@"action"] isEqualToString:@"showpost"]) && query[@"postid"]) {
            return [NSURL URLWithString:[NSString stringWithFormat:@"awful://posts/%@", query[@"postid"]]];
        } else if ([self.fragment hasPrefix:@"post"] && self.fragment.length > 4) {
            return [NSURL URLWithString:[NSString stringWithFormat:@"awful://posts/%@", [self.fragment substringFromIndex:4]]];
        }
        
        // Link to page on specific thread.
        else if (query[@"threadid"] && query[@"pagenumber"]) {
            NSString *extra = @"";
            
            // Oftentimes a copied SA URL will have `&userid=0` tacked on, which appears to mean "don't filter by author". Awful handles this by simply not specifying a userid.
            if (query[@"userid"] && ![query[@"userid"] isEqualToString:@"0"]) {
                extra = [NSString stringWithFormat:@"?userid=%@", query[@"userid"]];
            }
            return [NSURL URLWithString:[NSString stringWithFormat:@"awful://threads/%@/pages/%@%@",
                                         query[@"threadid"], query[@"pagenumber"], extra]];
        }
        
        // Link to specific thread.
        else if (query[@"threadid"]) {
            NSString *extra = @"";
            if (query[@"userid"]) {
                extra = [NSString stringWithFormat:@"?userid=%@", query[@"userid"]];
            }
            return [NSURL URLWithString:[NSString stringWithFormat:@"awful://threads/%@/pages/1%@", query[@"threadid"], extra]];
        }
    }
    
    // Forum.
    else if ([self.path caseInsensitiveCompare:@"/forumdisplay.php"] == NSOrderedSame) {
        if (query[@"forumid"]) {
            return [NSURL URLWithString:[NSString stringWithFormat:@"awful://forums/%@", query[@"forumid"]]];
        }
    }
    
    // Profile.
    else if ([self.path caseInsensitiveCompare:@"/member.php"] == NSOrderedSame) {
        if ([query[@"action"] isEqual:@"getinfo"] && query[@"userid"]) {
            return [NSURL URLWithString:[NSString stringWithFormat:@"awful://users/%@", query[@"userid"]]];
        }
    }
	
	// Rap Sheet/Lepers Colony.
    else if ([self.path caseInsensitiveCompare:@"/banlist.php"] == NSOrderedSame) {
		NSString *userId = query[@"userid"];
        if (userId) {
            return [NSURL URLWithString:[NSString stringWithFormat:@"awful://banlist/%@", query[@"userid"]]];
        }
		else {
			return [NSURL URLWithString:@"awful://banlist"];
		}
    }
    
    return nil;
}

@end
