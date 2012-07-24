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
}

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

@end
