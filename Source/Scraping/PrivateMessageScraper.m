//  PrivateMessageScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "PrivateMessageScraper.h"
#import "AuthorScraper.h"
#import "AwfulCompoundDateParser.h"
#import "AwfulErrorDomain.h"
#import "AwfulScanner.h"
#import <HTMLReader/HTMLTextNode.h>
#import "NSURL+QueryDictionary.h"
#import "Awful-Swift.h"

@interface PrivateMessageScraper ()

@property (strong, nonatomic) PrivateMessage *privateMessage;

@end

@implementation PrivateMessageScraper

- (void)scrape
{
    [super scrape];
    if (self.error) return;
    
    NSString *messageID;
    HTMLElement *replyLink = [self.node firstNodeMatchingSelector:@"div.buttons a"];
    NSURL *replyLinkURL = [NSURL URLWithString:replyLink[@"href"]];
    messageID = replyLinkURL.queryDictionary[@"privatemessageid"];
    if (messageID.length == 0) {
        NSString *message = @"Failed parsing private message; could not find messageID";
        self.error = [NSError errorWithDomain:AwfulErrorDomain code:AwfulErrorCodes.parseError userInfo:@{ NSLocalizedDescriptionKey: message }];
        return;
    }
    
    PrivateMessageKey *messageKey = [[PrivateMessageKey alloc] initWithMessageID:messageID];
    PrivateMessage *message = [PrivateMessage objectForKey:messageKey inManagedObjectContext:self.managedObjectContext];
    
    HTMLElement *breadcrumbs = [self.node firstNodeMatchingSelector:@"div.breadcrumbs b"];
    HTMLTextNode *subjectText = breadcrumbs.children.lastObject;
    if ([subjectText isKindOfClass:[HTMLTextNode class]]) {
        message.subject = subjectText.data;
    }
    
    HTMLElement *postDateCell = [self.node firstNodeMatchingSelector:@"td.postdate"];
    HTMLElement *iconImage = [postDateCell firstNodeMatchingSelector:@"img"];
    if (iconImage) {
        NSString *src = iconImage[@"src"];
        message.seen = [src rangeOfString:@"newpm"].location == NSNotFound;
        message.replied = [src rangeOfString:@"replied"].location != NSNotFound;
        message.forwarded = [src rangeOfString:@"forwarded"].location != NSNotFound;
    }
    
    NSString *sentDateText = [postDateCell.children.lastObject textContent];
    NSDate *sentDate = [[AwfulCompoundDateParser postDateParser] dateFromString:sentDateText];
    if (sentDate) {
        message.sentDate = sentDate;
    }
    
    HTMLElement *postBodyCell = [self.node firstNodeMatchingSelector:@"td.postbody"];
    if (postBodyCell) {
        message.innerHTML = postBodyCell.innerHTML;
    }
    
    AuthorScraper *authorScraper = [AuthorScraper scrapeNode:self.node intoManagedObjectContext:self.managedObjectContext];
    User *from = authorScraper.author;
    if (from) {
        message.from = from;
    }
    self.privateMessage = message;
}

@end
