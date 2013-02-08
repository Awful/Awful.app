//
//  AwfulParsing+Emoticons.m
//  Awful
//
//  Created by me on 1/11/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulParsing+Emoticons.h"
#import "AwfulModels.h"
#import "AwfulDataStack.h"
#import "AwfulHTTPClient+Emoticons.h"

#import "TFHpple.h"
#import "TFHppleElement.h"

@implementation EmoticonParsedInfo
- (void)parseHTMLData
{
    NSLog(@"got it... parsing smilies...");
    TFHpple *html = [[TFHpple alloc] initWithHTMLData:self.htmlData];
    
    //get all h3's, contain group names
    NSArray *groups = [html search:@"//h3"];
    
    //get all ul.smilie_group, contain emoticons
    NSArray* lists = [html search:@"//ul[@class='smilie_group']"];
    
    
    //check lengths match, if not this parsing is out of date
    if (groups.count != lists.count) {
        [NSException raise:@"Emoticon parsing error"
                    format:@"Couldn't parse the emoticon list. Most likely the forum code is updated and this app is not up do date."];
    }
    
    //walk through both lists and create emoticons
    NSMutableArray *emotes = [NSMutableArray new];
    for(NSUInteger i=0; i<groups.count; i++)
    {
        AwfulEmoticonGroup *g = [AwfulEmoticonGroup insertNew];
        g.desc = [[groups objectAtIndex:i] content];
        
        
        TFHppleElement* ul = [lists objectAtIndex:i];
        for(TFHppleElement* li in ul.children)
        {
            TFHppleElement *text = [li firstChildWithTagName:@"div"];
            TFHppleElement *img = [li firstChildWithTagName:@"img"];
            if(text != nil && img != nil) {
                AwfulEmoticon *s = [AwfulEmoticon insertNew];
                s.code = [text content];
                s.urlString = [img objectForKey:@"src"];
                s.desc = [img objectForKey:@"title"];
                s.group = g;
                [emotes addObject:s];
            }

        
        }
        
    }
    
    [[AwfulDataStack sharedDataStack] save];
    
    //[[AwfulHTTPClient client] downloadUncachedEmoticons];
}

@end
