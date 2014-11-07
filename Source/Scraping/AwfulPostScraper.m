//  AwfulPostScraper.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPostScraper.h"
#import "AwfulAuthorScraper.h"
#import "AwfulErrorDomain.h"
#import "AwfulScanner.h"
#import "Awful-Swift.h"

@interface AwfulPostScraper ()

@property (strong, nonatomic) Post *post;

@end

@implementation AwfulPostScraper

- (void)scrape
{
    [super scrape];
    if (self.error) return;
    
    // Presumably we're scraping a post that wasn't previously shown because its author is ignored. The only information that's hidden in that case, and thus the information we need to get here, is some author info (namely avatar) and the post contents.
    
    HTMLElement *table = [self.node firstNodeMatchingSelector:@"table.post[id]"];
    
    {{
        AwfulScanner *scanner = [AwfulScanner scannerWithString:table[@"id"]];
        NSCharacterSet *digitCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"];
        [scanner scanUpToCharactersFromSet:digitCharacterSet intoString:nil];
        NSString *postID;
        if (![scanner scanCharactersFromSet:digitCharacterSet intoString:&postID]) {
            self.error = [NSError errorWithDomain:AwfulErrorDomain
                                             code:AwfulErrorCodes.parseError
                                         userInfo:@{ NSLocalizedDescriptionKey: @"Post parsing failed; could not find post ID" }];
            return;
        }
        self.post = [Post firstOrNewPostWithPostID:postID inManagedObjectContext:self.managedObjectContext];
    }}
    
    {{
        AwfulAuthorScraper *authorScraper = [AwfulAuthorScraper scrapeNode:table intoManagedObjectContext:self.managedObjectContext];
        self.post.author = authorScraper.author;
    }}
    
    {{
        HTMLElement *postBodyElement = ([table firstNodeMatchingSelector:@"div.complete_shit"] ?:
                                        [table firstNodeMatchingSelector:@"td.postbody"]);
        if (postBodyElement) {
            self.post.innerHTML = postBodyElement.innerHTML;
        }
    }}
}

@end
