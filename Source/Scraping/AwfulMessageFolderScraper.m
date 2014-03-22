//  AwfulMessageFolderScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulMessageFolderScraper.h"
#import "AwfulCompoundDateParser.h"
#import "AwfulErrorDomain.h"
#import "GTMNSString+HTML.h"
#import "HTMLNode+CachedSelector.h"
#import "NSURL+QueryDictionary.h"

@interface AwfulMessageFolderScraper ()

@property (strong, nonatomic) AwfulCompoundDateParser *sentDateParser;

@end

@implementation AwfulMessageFolderScraper

- (AwfulCompoundDateParser *)sentDateParser
{
    if (_sentDateParser) return _sentDateParser;
    _sentDateParser = [[AwfulCompoundDateParser alloc] initWithFormats:@[
                                                                        @"MMM d, yyyy 'at' h:mm a",
                                                                        @"MMMM d, yyyy 'at' HH:mm",
                                                                        ]];
    return _sentDateParser;
}

#pragma mark - AwfulDocumentScraper

- (id)scrapeDocument:(HTMLDocument *)document
             fromURL:(NSURL *)documentURL
intoManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
               error:(out NSError *__autoreleasing *)error
{
    NSMutableArray *messages = [NSMutableArray new];
    NSArray *rows = [document awful_nodesMatchingCachedSelector:@"table.standard tbody tr"];
    for (HTMLElement *row in rows) {
        HTMLElement *titleLink = [row awful_firstNodeMatchingCachedSelector:@"td.title a"];
        NSString *messageID; {
            NSURL *URL = [NSURL URLWithString:titleLink[@"href"]];
            messageID = URL.queryDictionary[@"privatemessageid"];
        }
        if (messageID.length == 0) {
            if (error) {
                *error = [NSError errorWithDomain:AwfulErrorDomain
                                             code:AwfulErrorCodes.parseError
                                         userInfo:@{ NSLocalizedDescriptionKey: @"Failed to parse message in folder; could not find message ID" }];
            }
            continue;
        }
        AwfulPrivateMessage *message = [AwfulPrivateMessage firstOrNewPrivateMessageWithMessageID:messageID inManagedObjectContext:managedObjectContext];
        message.subject = [titleLink.innerHTML gtm_stringByUnescapingFromHTML];
        {
            HTMLElement *seenImage = [row awful_firstNodeMatchingCachedSelector:@"td.status img"];
            NSString *src = seenImage[@"src"];
            message.seen = [src rangeOfString:@"newpm"].location == NSNotFound;
            message.replied = [src rangeOfString:@"replied"].location != NSNotFound;
            message.forwarded = [src rangeOfString:@"forwarded"].location != NSNotFound;
        }
        {
            HTMLElement *threadTagImage = [row awful_firstNodeMatchingCachedSelector:@"td.icon img"];
            if (threadTagImage) {
                NSURL *URL = [NSURL URLWithString:threadTagImage[@"src"] relativeToURL:documentURL];
                message.threadTag = [AwfulThreadTag firstOrNewThreadTagWithThreadTagID:nil
                                                                          threadTagURL:URL
                                                                inManagedObjectContext:managedObjectContext];
            } else {
                message.threadTag = nil;
            }
        }
        {
            HTMLElement *fromCell = [row awful_firstNodeMatchingCachedSelector:@"td.sender"];
            NSString *fromUsername = [fromCell.innerHTML gtm_stringByUnescapingFromHTML];
            if (fromUsername.length > 0) {
                message.from = [AwfulUser firstOrNewUserWithUserID:nil
                                                          username:fromUsername
                                            inManagedObjectContext:managedObjectContext];
            }
        }
        {
            HTMLElement *sentDateCell = [row awful_firstNodeMatchingCachedSelector:@"td.date"];
            NSDate *sentDate = [self.sentDateParser dateFromString:sentDateCell.innerHTML];
            if (sentDate) {
                message.sentDate = sentDate;
            }
        }
        [messages addObject:message];
    }
    [managedObjectContext save:error];
    return messages;
}

@end
