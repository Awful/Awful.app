#import "AwfulEmote.h"
#import "TFHpple.h"

@implementation AwfulEmote

-(id) init {
    self = [super initWithEntity:[NSEntityDescription entityForName:[[self class] description]
                                             inManagedObjectContext:ApplicationDelegate.managedObjectContext
                                  ]
  insertIntoManagedObjectContext:ApplicationDelegate.managedObjectContext];
    
    return self;
}

+(NSArray*)parseEmoticonsWithData : (NSData *)data
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
            s.filename = [[img objectForKey:@"src"] lastPathComponent];
            s.desc = [img objectForKey:@"title"];
            //s.cacheDate = [NSDate date];
            //s.category = something;
            
            [smilies addObject:s];
        }
    }
    NSLog(@"found %d emotes", smilies.count);
    [ApplicationDelegate saveContext];
    return smilies;
}

@end
