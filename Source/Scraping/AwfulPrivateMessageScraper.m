//  AwfulPrivateMessageScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPrivateMessageScraper.h"
#import "AwfulAuthorScraper.h"
#import "AwfulCompoundDateParser.h"
#import "AwfulErrorDomain.h"
#import "AwfulScanner.h"
#import "GTMNSString+HTML.h"
#import "HTMLNode+CachedSelector.h"
#import <HTMLReader/HTMLTextNode.h>
#import "NSURL+QueryDictionary.h"

@interface AwfulPrivateMessageScraper ()

@property (strong, nonatomic) AwfulCompoundDateParser *sentDateParser;
@property (strong, nonatomic) AwfulAuthorScraper *authorScraper;

@end

@implementation AwfulPrivateMessageScraper

- (AwfulCompoundDateParser *)sentDateParser
{
    if (!_sentDateParser) _sentDateParser = [AwfulCompoundDateParser postDateParser];
    return _sentDateParser;
}

- (AwfulAuthorScraper *)authorScraper
{
    if (!_authorScraper) _authorScraper = [AwfulAuthorScraper new];
    return _authorScraper;
}

#pragma mark - AwfulDocumentScraper

- (id)scrapeDocument:(HTMLDocument *)document
             fromURL:(NSURL *)documentURL
intoManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
               error:(out NSError **)error
{
    NSString *messageID;
    HTMLElement *replyLink = [document awful_firstNodeMatchingCachedSelector:@"div.buttons a"];
    NSURL *replyLinkURL = [NSURL URLWithString:replyLink[@"href"]];
    messageID = replyLinkURL.queryDictionary[@"privatemessageid"];
    if (messageID.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:AwfulErrorDomain
                                         code:AwfulErrorCodes.parseError
                                     userInfo:@{ NSLocalizedDescriptionKey: @"Failed parsing private message; could not find messageID" }];
        }
        return nil;
    }
    AwfulPrivateMessage *message = [AwfulPrivateMessage firstOrNewPrivateMessageWithMessageID:messageID
                                                                       inManagedObjectContext:managedObjectContext];
    HTMLElement *breadcrumbs = [document awful_firstNodeMatchingCachedSelector:@"div.breadcrumbs b"];
    HTMLTextNode *subjectText = breadcrumbs.children.lastObject;
    if ([subjectText isKindOfClass:[HTMLTextNode class]]) {
        message.subject = [subjectText.data gtm_stringByUnescapingFromHTML];
    }
    HTMLElement *postDateCell = [document awful_firstNodeMatchingCachedSelector:@"td.postdate"];
    HTMLElement *iconImage = [postDateCell awful_firstNodeMatchingCachedSelector:@"img"];
    if (iconImage) {
        NSString *src = iconImage[@"src"];
        message.seen = [src rangeOfString:@"newpm"].location == NSNotFound;
        message.replied = [src rangeOfString:@"replied"].location != NSNotFound;
        message.forwarded = [src rangeOfString:@"forwarded"].location != NSNotFound;
    }
    HTMLTextNode *sentDateText = postDateCell.children.lastObject;
    if ([sentDateText isKindOfClass:[HTMLTextNode class]]) {
        NSDate *sentDate = [self.sentDateParser dateFromString:sentDateText.data];
        if (sentDate) {
            message.sentDate = sentDate;
        }
    }
    HTMLElement *postBodyCell = [document awful_firstNodeMatchingCachedSelector:@"td.postbody"];
    if (postBodyCell) {
        message.innerHTML = postBodyCell.innerHTML;
    }
    AwfulUser *from = [self.authorScraper scrapeAuthorFromNode:document intoManagedObjectContext:managedObjectContext];
    if (from) {
        message.from = from;
    }
    return message;
}

@end
