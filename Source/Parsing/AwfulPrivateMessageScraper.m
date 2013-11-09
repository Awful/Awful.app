//  AwfulPrivateMessageScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPrivateMessageScraper.h"
#import "AwfulCompoundDateParser.h"
#import "AwfulErrorDomain.h"
#import "AwfulScanner.h"
#import "GTMNSString+HTML.h"
#import "NSURL+QueryDictionary.h"

@interface AwfulPrivateMessageScraper ()

@property (strong, nonatomic) AwfulCompoundDateParser *sentDateParser;
@property (strong, nonatomic) AwfulCompoundDateParser *regdateDateParser;

@end

@implementation AwfulPrivateMessageScraper

- (AwfulCompoundDateParser *)sentDateParser
{
    if (!_sentDateParser) _sentDateParser = [AwfulCompoundDateParser postDateParser];
    return _sentDateParser;
}

- (AwfulCompoundDateParser *)regdateDateParser
{
    if (!_regdateDateParser) _regdateDateParser = [AwfulCompoundDateParser regdateDateParser];
    return _regdateDateParser;
}

#pragma mark - AwfulDocumentScraper

- (id)scrapeDocument:(HTMLDocument *)document
             fromURL:(NSURL *)documentURL
intoManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
               error:(out NSError **)error
{
    NSString *messageID;
    HTMLElementNode *replyLink = [document firstNodeMatchingSelector:@"div.buttons a"];
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
    HTMLElementNode *breadcrumbs = [document firstNodeMatchingSelector:@"div.breadcrumbs b"];
    HTMLTextNode *subjectText = breadcrumbs.childNodes.lastObject;
    if ([subjectText isKindOfClass:[HTMLTextNode class]]) {
        message.subject = [subjectText.data gtm_stringByUnescapingFromHTML];
    }
    HTMLElementNode *postDateCell = [document firstNodeMatchingSelector:@"td.postdate"];
    HTMLElementNode *iconImage = [postDateCell firstNodeMatchingSelector:@"img"];
    if (iconImage) {
        NSString *src = iconImage[@"src"];
        message.seen = [src rangeOfString:@"newpm"].location == NSNotFound;
        message.replied = [src rangeOfString:@"replied"].location != NSNotFound;
        message.forwarded = [src rangeOfString:@"forwarded"].location != NSNotFound;
    }
    HTMLTextNode *sentDateText = postDateCell.childNodes.lastObject;
    if ([sentDateText isKindOfClass:[HTMLTextNode class]]) {
        NSDate *sentDate = [self.sentDateParser dateFromString:sentDateText.data];
        if (sentDate) {
            message.sentDate = sentDate;
        }
    }
    HTMLElementNode *postBodyCell = [document firstNodeMatchingSelector:@"td.postbody"];
    if (postBodyCell) {
        message.innerHTML = postBodyCell.innerHTML;
    }
    HTMLElementNode *fromProfileLink = [document firstNodeMatchingSelector:@"ul.profilelinks a"];
    NSURL *fromProfileLinkURL = [NSURL URLWithString:fromProfileLink[@"href"]];
    NSString *fromUserID = fromProfileLinkURL.queryDictionary[@"userid"];
    HTMLElementNode *fromUsernameTerm = [document firstNodeMatchingSelector:@"dl.userinfo dt.author"];
    NSString *fromUsername = [fromUsernameTerm.innerHTML gtm_stringByUnescapingFromHTML];
    AwfulUser *from = [AwfulUser firstOrNewUserWithUserID:fromUserID
                                                 username:fromUsername
                                   inManagedObjectContext:managedObjectContext];
    if (fromUsernameTerm) {
        NSArray *classes = [fromUsernameTerm[@"class"] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        from.administrator = [classes containsObject:@"role-admin"];
        from.moderator = [classes containsObject:@"role-mod"];
    }
    HTMLElementNode *regdateDefinition = [document firstNodeMatchingSelector:@"dl.userinfo dd.registered"];
    if (regdateDefinition) {
        NSDate *regdate = [self.regdateDateParser dateFromString:regdateDefinition.innerHTML];
        if (regdate) {
            from.regdate = regdate;
        }
    }
    HTMLElementNode *customTitleDefinition = [document firstNodeMatchingSelector:@"dl.userinfo dd.title"];
    if (customTitleDefinition) {
        from.customTitleHTML = customTitleDefinition.innerHTML;
    }
    message.from = from;
    return message;
}

@end
