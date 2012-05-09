//
//  AwfulEmote+AwfulMethods.m
//  Awful
//
//  Created by me on 5/7/12.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulEmote+AwfulMethods.h"
#import "TFHpple.h"

@implementation AwfulEmote (AwfulMethods)

+(void)parseEmotesWithData : (NSData *)data
{
    NSLog(@"got it... parsing smilies...");
    TFHpple *page_data = [[TFHpple alloc] initWithHTMLData:data];
    
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
            s.urlString = [img objectForKey:@"src"];
            s.desc = [img objectForKey:@"title"];
            s.cacheDate = [NSDate date];
            //s.category = something;
            
            [smilies addObject:s];
        }
    }
    NSLog(@"found %d emotes", smilies.count);
    [ApplicationDelegate saveContext];
}

-(BOOL) cached {
    return (self.imageData.length > 0) ;
}

@end
