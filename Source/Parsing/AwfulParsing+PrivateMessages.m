//
//  AwfulParsing+PrivateMessages.m
//  Awful
//
//  Created by me on 1/7/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulParsing+PrivateMessages.h"
#import "AwfulDataStack.h"
#import "XPathQuery.h"
#import "TFHpple.h"
#import "TFHppleElement.h"

@implementation PrivateMessageParsedInfo
+(NSMutableArray *)parsePMListWithData:(NSData*)data
{
    //TFHpple *page_data = [[TFHpple alloc] initWithHTMLData:data];
    /*
     NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"AwfulPM"];
     NSError *error;
     NSArray *existingForums = [ApplicationDelegate.managedObjectContext executeFetchRequest:request
     error:&error
     ];
     NSMutableDictionary *existingDict = [NSMutableDictionary new];
     for (AwfulForum* f in existingForums)
     [existingDict setObject:f forKey:f.forumID];
     
     */
    
    NSArray *rows = PerformRawHTMLXPathQuery(data, @"//tr");
    for (NSString* r in rows) {
        NSData *d = [r dataUsingEncoding:NSUTF8StringEncoding];
        AwfulPrivateMessage *message = [AwfulPrivateMessage insertNew];
        
        NSArray *cells = PerformRawHTMLXPathQuery(d, @"//td");
        for (NSUInteger j=0; j<cells.count; j++) {
            TFHpple* cell = [[TFHpple alloc] initWithHTMLData:[[cells objectAtIndex:j] dataUsingEncoding:NSUTF8StringEncoding]];
            TFHppleElement *element;
            
            TFHppleElement* tagImageElement;
            switch (j) {
                case 0: //image
                    element = [cell searchForSingle:@"//img"];
                    message.repliedValue = [[element objectForKey:@"src"] rangeOfString:@"replied"].location != NSNotFound;
                    break;
                    
                case 1: //tag image
                    element = [cell searchForSingle:@"//img"];
                    if (element)
                        tagImageElement = element;
                    break;
                    
                case 2: //link with subject and id
                    element = [cell searchForSingle:@"//a"];
                    if (element) {
                        message.subject = element.content;
                        message.messageIDValue = [[self messageIDFromLinkElement:element] intValue];
                    }
                    break;
                    
                case 3: //from
                    element = [cell searchForSingle:@"//td"];
                    message.from = element.content;
                    break;
                    
                case 4: //sent date
                    element = [cell searchForSingle:@"//td"];
                    message.sent = [self dateFromElement:element];
                    break;
                    
            }
            
            if (tagImageElement) {
                NSString* src = [tagImageElement objectForKey:@"src"];
                message.threadIconImageURL = src;
            }
             
        }
    }
    
    [[AwfulDataStack sharedDataStack] save];
    return nil;
}

+(NSDate*) dateFromElement:(TFHppleElement*)element {
    static NSDateFormatter *df = nil;
    if(df == nil) {
        df = [[NSDateFormatter alloc] init];
        [df setTimeZone:[NSTimeZone localTimeZone]];
        [df setDateFormat:@"MMM d, yyyy 'at' HH:mm"];
    }
    
    NSDate *myDate = [df dateFromString:[element content]];
    return myDate;
}

+(NSString*) messageIDFromLinkElement:(TFHppleElement*)a {
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"privatemessageid=([0-9]*)"
                                                                           options:NSRegularExpressionCaseInsensitive
                                                                             error:nil];
    NSString *href = [a objectForKey:@"href"];
    NSRange range = [[regex firstMatchInString:href
                                       options:0
                                         range:NSMakeRange(0,href.length)]
                     rangeAtIndex:1];
    return  [href substringWithRange:range];
}

+(NSMutableArray *)parsePM:(AwfulPrivateMessage*)message withData:(NSData*)data
{
    NSArray *rows = PerformRawHTMLXPathQuery(data, @"//td[@class='postbody']");
    for (NSString* r in rows) {
        message.content = r;
    }
    [[AwfulDataStack sharedDataStack] save];
    return nil;
}

@end
