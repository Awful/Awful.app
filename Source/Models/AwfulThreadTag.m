#import "AwfulThreadTag.h"
#import "TFHpple.h"

@implementation AwfulThreadTag

+(NSArray*)parseThreadTagsForForum:(AwfulForum*)forum withData : (NSData *)data
{
    TFHpple *page_data = [[TFHpple alloc] initWithHTMLData:data];
    
    NSMutableArray *tags = [NSMutableArray new];
    
    NSArray *tag_html = [page_data rawSearch:@"//div[@class='posticon']"];
    for(NSString *html in tag_html) {
        TFHpple *sm = [[TFHpple alloc] initWithHTMLData:[html dataUsingEncoding:NSUTF8StringEncoding]];
        TFHppleElement *radio = [sm searchForSingle:@"//input"];
        TFHppleElement *img = [sm searchForSingle:@"//img"];
        if(img != nil) {
            AwfulThreadTag *tag = [NSEntityDescription insertNewObjectForEntityForName:@"AwfulThreadTag"
                                                                inManagedObjectContext:ApplicationDelegate.managedObjectContext];
            tag.filename = [img objectForKey:@"src"];
            tag.alt = [img objectForKey:@"alt"];
            tag.tagIDValue = [radio objectForKey:@"value"].integerValue;
            //[tag.forumsSet addObject:forum];
            
            [tags addObject:tag];
        }
    }
    NSLog(@"found %d tags", tags.count);
    [ApplicationDelegate saveContext];
    return tags;
}

+(void) cacheThreadTag:(AwfulThreadTag *)threadTag data:(NSData *)data {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSArray* dirPaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString* docsDir = [dirPaths objectAtIndex:0];
    
    [fileManager changeCurrentDirectoryPath: docsDir];
    [fileManager createFileAtPath:threadTag.filename.lastPathComponent contents:data attributes:nil];
    NSString* path = [docsDir stringByAppendingPathComponent:threadTag.filename.lastPathComponent];
    NSURL *url = [NSURL fileURLWithPath:path];
    threadTag.filename = url.absoluteString;
    [ApplicationDelegate saveContext];
}


-(UIImage*) image {
    NSURL *url = [NSURL URLWithString:self.filename];
    if (url.isFileURL) {
        return [UIImage imageWithContentsOfFile:url.path];
    }
    return nil;
}

@end
