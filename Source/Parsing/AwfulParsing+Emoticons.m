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
    
    //TFHpple *page_data = [[TFHpple alloc] initWithHTMLData:self.htmlData];
    /*
    NSMutableArray *smilies = [NSMutableArray new];
    
    NSArray *smilie_html = [page_data rawSearch:@"//li[@class='smilie']"];
    for(NSString *html in smilie_html) {
        TFHpple *sm = [[TFHpple alloc] initWithHTMLData:[html dataUsingEncoding:NSUTF8StringEncoding]];
        TFHppleElement *text = [sm searchForSingle:@"//div[@class='text']"];
        TFHppleElement *img = [sm searchForSingle:@"//img"];
        if(text != nil && img != nil) {
            AwfulEmote *s = [NSEntityDescription insertNewObjectForEntityForName:@"AwfulEmote"
                                                          inManagedObjectContext:ApplicationDelegate.managedObjectContext];
            s.code = [text content];
            s.filename = [img objectForKey:@"src"];
            s.desc = [img objectForKey:@"title"];
            //s.cacheDate = [NSDate date];
            //s.category = something;
            
            [smilies addObject:s];
        }
    }
    NSLog(@"found %d emotes", smilies.count);
    [ApplicationDelegate saveContext];
    return smilies;
     */
}
/*
+(void) cacheEmoticon:(AwfulEmote*)emote data:(NSData*)data {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSArray* dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* docsDir = [dirPaths objectAtIndex:0];
    
    [fileManager changeCurrentDirectoryPath: docsDir];
    [fileManager createFileAtPath:emote.filename.lastPathComponent contents:data attributes:nil];
    NSString* path = [docsDir stringByAppendingPathComponent:emote.filename.lastPathComponent];
    NSURL *url = [NSURL fileURLWithPath:path];
    emote.filename = url.absoluteString;
    [ApplicationDelegate saveContext];
}

-(BOOL) isCached {
    NSString *path = [[NSBundle mainBundle] pathForResource:self.filename.lastPathComponent ofType:nil];
    if (path) {
        self.filename = self.filename.lastPathComponent;
        return YES;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray* dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* docsDir = [dirPaths objectAtIndex:0];
    
    [fileManager changeCurrentDirectoryPath: docsDir];
    if ([fileManager fileExistsAtPath:self.filename.lastPathComponent]) {
        self.filename = self.filename.lastPathComponent;
        return YES;
    }
    
    return NO;
}
*/
@end
