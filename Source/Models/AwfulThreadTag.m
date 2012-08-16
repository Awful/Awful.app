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
    threadTag.filename = path;
    [ApplicationDelegate saveContext];
}


-(UIImage*) image {
    if (![self.filename hasPrefix:@"http"]) {
        //UIImage *img = [UIImage imageWithContentsOfFile:self.filename];
        return [UIImage imageWithContentsOfFile:self.filename];
    }
    return nil;
}

+(void) updateTags:(NSArray*)tags forForum:(AwfulForum*)forum {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AwfulThreadTag"];
    NSError *error;
    NSArray *existingTags = [ApplicationDelegate.managedObjectContext executeFetchRequest:request
                                                                                      error:&error
                               ];
    
    NSMutableDictionary *existingDict = [NSMutableDictionary new];
    for (AwfulThreadTag* t in existingTags)
        [existingDict setObject:t forKey:t.tagID];
    
    for (NSString* tag in tags) {
        TFHpple *tag_base = [[TFHpple alloc] initWithHTMLData:[tag dataUsingEncoding:NSUTF8StringEncoding]];
        
        TFHppleElement* a = [tag_base searchForSingle:@"//a"];
        TFHppleElement* img = [tag_base searchForSingle:@"//img"];
        
        AwfulThreadTag *newTag = [existingDict objectForKey:[self tagIDFromLinkElement:a]];
        if (!newTag) {
            newTag = [AwfulThreadTag new];
            newTag.filename = [img objectForKey:@"src"];
            newTag.alt = [img objectForKey:@"alt"];
            newTag.tagID = [self tagIDFromLinkElement:a];
        }
        [forum addThreadTagsObject:newTag];
    }
}

+(NSNumber*) tagIDFromLinkElement:(TFHppleElement*)a {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"posticon=([0-9]*)"
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:nil];
    NSString *href = [a objectForKey:@"href"];
    NSRange range = [[regex firstMatchInString:href
                                       options:0
                                         range:NSMakeRange(0,href.length)]
                     rangeAtIndex:1];
    int tagID = [[href substringWithRange:range] intValue];
    return  [NSNumber numberWithInt:tagID];
}
@end
