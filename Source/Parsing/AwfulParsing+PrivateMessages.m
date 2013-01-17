//
//  AwfulParsing+PrivateMessages.m
//  Awful
//
//  Created by me on 1/7/13.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulParsing.h"
#import "AwfulParsing+PrivateMessages.h"
#import "AwfulDataStack.h"
#import "XPathQuery.h"
#import "TFHpple.h"
#import "TFHppleElement.h"

@interface PrivateMessageParsedInfo ()
@property (copy, nonatomic) NSString *messageID;
@property (copy, nonatomic) NSString *subject;
@property (nonatomic) NSDate* sent;
@property (nonatomic) NSURL *messageIconImageURL;
@property (nonatomic) UserParsedInfo *from;
@property (nonatomic) BOOL seen;
@property (nonatomic) BOOL replied;
@property (nonatomic) NSString* innerHTML;
@end

@implementation PrivateMessageParsedInfo

+ (NSArray *)messagesWithHTMLData:(NSData *)htmlData
{
    NSMutableArray *msgs = [NSMutableArray new];
    NSArray *rawPMs = PerformRawHTMLXPathQuery(htmlData, @"//tr");
    for (NSString *onePM in rawPMs) {
        NSData *dataForOnePM = [onePM dataUsingEncoding:NSUTF8StringEncoding];
        PrivateMessageParsedInfo *info = [[self alloc] initWithHTMLData:dataForOnePM];
        if (info.messageID)
            [msgs addObject:info];
    }
    return msgs;
}

- (void)parseHTMLData
{
        NSArray *cells = PerformRawHTMLXPathQuery(self.htmlData, @"//td");
    
        for (NSUInteger j=0; j<cells.count; j++) {
            TFHpple* cell = [[TFHpple alloc] initWithHTMLData:[[cells objectAtIndex:j] dataUsingEncoding:NSUTF8StringEncoding]];
            TFHppleElement *element;
            
            switch (j) {
                case 0: //image
                    element = [cell searchForSingle:@"//img"];
                    self.replied = [[element objectForKey:@"src"] rangeOfString:@"replied"].location != NSNotFound;
                    self.seen = [[element objectForKey:@"src"] rangeOfString:@"newpm"].location == NSNotFound;
                    break;
                    
                case 1: //tag image
                    element = [cell searchForSingle:@"//img"];
                    if (element)
                        self.messageIconImageURL = [NSURL URLWithString:[element objectForKey:@"src"]];
                    break;
                    
                case 2: //link with subject and id
                    element = [cell searchForSingle:@"//a"];
                    if (element) {
                        self.subject = element.content;
                        self.messageID = [self messageIDFromLinkElement:element];
                    }
                    break;
                    
                case 3: //from
                    element = [cell searchForSingle:@"//td"];
                    self.from = [UserParsedInfo new];
                    self.from.username = element.content;
                    break;
                    
                case 4: //sent date
                    element = [cell searchForSingle:@"//td"];
                    self.sent = [self dateFromElement:element];
                    break;
                    
            }
        }
    
}

-(NSDate*) dateFromElement:(TFHppleElement*)element {
    static NSDateFormatter *df = nil;
    if(df == nil) {
        df = [[NSDateFormatter alloc] init];
        [df setTimeZone:[NSTimeZone localTimeZone]];
        [df setDateFormat:@"MMM d, yyyy 'at' HH:mm"];
    }
    
    NSDate *myDate = [df dateFromString:[element content]];
    return myDate;
}

- (NSString*) messageIDFromLinkElement:(TFHppleElement*)a {
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

+(void)parsePM:(AwfulPrivateMessage*)message withData:(NSData*)data
{
    NSArray *rows = PerformRawHTMLXPathQuery(data, @"//td[@class='postbody']");
    for (NSString* r in rows) {
        message.innerHTML = r;
    }
    [[AwfulDataStack sharedDataStack] save];
}

+ (NSArray *)keysToApplyToObject
{
    return @[
    @"messageID", @"subject", @"messageIconImageURL",
    @"seen", @"replied", @"sent", @"innerHTML"
    ];
}

@end
