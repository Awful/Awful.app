//  PrivateMessageFolderScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "PrivateMessageFolderScraper.h"
#import "AwfulCompoundDateParser.h"
#import <AwfulCore/AwfulCore-Swift.h>

@interface PrivateMessageFolderScraper ()

@property (copy, nonatomic) NSArray *messages;

@end

@implementation PrivateMessageFolderScraper

- (void)scrape
{
    [super scrape];
    if (self.error) return;
    
    NSMutableArray *messages = [NSMutableArray new];
    NSArray *rows = [self.node nodesMatchingSelector:@"table.standard tbody tr"];
    for (HTMLElement *row in rows) {
        HTMLElement *titleLink = [row firstNodeMatchingSelector:@"td.title a"];
        NSString *messageID; {
            NSURL *URL = [NSURL URLWithString:titleLink[@"href"]];
            messageID = URL.awful_queryDictionary[@"privatemessageid"];
        }
        if (messageID.length == 0) {
            NSString *message = @"Failed to parse message in folder; could not find message ID";
            self.error = [NSError errorWithDomain:AwfulCoreError.domain code:AwfulCoreError.parseError userInfo:@{ NSLocalizedDescriptionKey: message }];
            continue;
        }
        
        PrivateMessageKey *messageKey = [[PrivateMessageKey alloc] initWithMessageID:messageID];
        PrivateMessage *message = [PrivateMessage objectForKey:messageKey inManagedObjectContext:self.managedObjectContext];
        message.subject = titleLink.textContent;
        
        {{
            HTMLElement *seenImage = [row firstNodeMatchingSelector:@"td.status img"];
            NSString *src = seenImage[@"src"];
            message.seen = [src rangeOfString:@"newpm"].location == NSNotFound;
            message.replied = [src rangeOfString:@"replied"].location != NSNotFound;
            message.forwarded = [src rangeOfString:@"forwarded"].location != NSNotFound;
        }}
        
        {{
            HTMLElement *threadTagImage = [row firstNodeMatchingSelector:@"td.icon img"];
            NSURL *URL = [NSURL URLWithString:threadTagImage[@"src"]];
            if (URL) {
                ThreadTagKey *tagKey = [[ThreadTagKey alloc] initWithImageURL:URL threadTagID:nil];
                message.threadTag = [ThreadTag objectForKey:tagKey inManagedObjectContext:self.managedObjectContext];
            } else {
                message.threadTag = nil;
            }
        }}
        
        {{
            HTMLElement *fromCell = [row firstNodeMatchingSelector:@"td.sender"];
            NSString *fromUsername = fromCell.textContent;
            if (fromUsername.length > 0) {
                message.rawFromUsername = fromUsername;
            }
        }}
        
        {{
            HTMLElement *sentDateCell = [row firstNodeMatchingSelector:@"td.date"];
            NSDate *sentDate = [SentDateParser() dateFromString:sentDateCell.innerHTML];
            if (sentDate) {
                message.sentDate = sentDate;
            }
        }}
        
        [messages addObject:message];
    }
    self.messages = messages;
}

static AwfulCompoundDateParser * SentDateParser(void)
{
    static AwfulCompoundDateParser *parser;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        parser = [[AwfulCompoundDateParser alloc] initWithFormats:@[ @"MMM d, yyyy 'at' h:mm a",
                                                                     @"MMMM d, yyyy 'at' HH:mm" ]];
    });
    return parser;
}

@end
