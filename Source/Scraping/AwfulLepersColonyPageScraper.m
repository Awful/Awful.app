//  AwfulLepersColonyPageScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulLepersColonyPageScraper.h"
#import "AwfulCompoundDateParser.h"
#import "GTMNSString+HTML.h"
#import "HTMLNode+CachedSelector.h"
#import "NSURL+QueryDictionary.h"

@interface AwfulLepersColonyPageScraper ()

@property (strong, nonatomic) AwfulCompoundDateParser *dateParser;

@end

@implementation AwfulLepersColonyPageScraper

- (AwfulCompoundDateParser *)dateParser
{
    if (_dateParser) return _dateParser;
    _dateParser = [[AwfulCompoundDateParser alloc] initWithFormats:@[
                                                                    @"MM/dd/yy hh:mma",
                                                                    ]];
    return _dateParser;
}

#pragma mark - AwfulDocumentScraper

- (id)scrapeDocument:(HTMLDocument *)document
             fromURL:(NSURL *)documentURL
intoManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
               error:(out NSError *__autoreleasing *)error
{
    NSMutableArray *bans = [NSMutableArray new];
    NSArray *rows = [document awful_nodesMatchingCachedSelector:@"table.standard tr"];
    
    // First row just has headers.
    rows = [rows subarrayWithRange:NSMakeRange(1, rows.count - 1)];
    
    for (HTMLElementNode *row in rows) {
        AwfulBan *ban = [AwfulBan new];
        HTMLElementNode *typeCell = [row awful_firstNodeMatchingCachedSelector:@"td:nth-of-type(1)"];
        {
            HTMLElementNode *typeLink = [typeCell awful_firstNodeMatchingCachedSelector:@"a"];
            NSURL *URL = [NSURL URLWithString:typeLink[@"href"]];
            NSString *postID = URL.queryDictionary[@"postid"];
            if (postID) {
                ban.post = [AwfulPost firstOrNewPostWithPostID:postID inManagedObjectContext:managedObjectContext];
            }
        }
        {
            NSString *typeHTML = typeCell.innerHTML;
            if ([typeHTML rangeOfString:@"PROBATION"].location != NSNotFound) {
                ban.punishment = AwfulPunishmentProbation;
            } else if ([typeHTML rangeOfString:@"PERMABAN"].location != NSNotFound) {
                ban.punishment = AwfulPunishmentPermaban;
            } else if ([typeHTML rangeOfString:@"BAN"].location != NSNotFound) {
                ban.punishment = AwfulPunishmentBan;
            }
        }
        {
            HTMLElementNode *dateCell = [row awful_firstNodeMatchingCachedSelector:@"td:nth-of-type(2)"];
            NSDate *date = [self.dateParser dateFromString:dateCell.innerHTML];
            if (date) {
                ban.date = date;
            }
        }
        {
            HTMLElementNode *userLink = [row awful_firstNodeMatchingCachedSelector:@"td:nth-of-type(3) a"];
            NSURL *URL = [NSURL URLWithString:userLink[@"href"]];
            NSString *userID = URL.queryDictionary[@"userid"];
            NSString *username = [userLink.innerHTML gtm_stringByUnescapingFromHTML];
            AwfulUser *user = [AwfulUser firstOrNewUserWithUserID:userID
                                                         username:username
                                           inManagedObjectContext:managedObjectContext];
            if (user) {
                ban.user = user;
            }
        }
        {
            HTMLElementNode *reasonCell = [row awful_firstNodeMatchingCachedSelector:@"td:nth-of-type(4)"];
            ban.reasonHTML = reasonCell.innerHTML;
        }
        {
            HTMLElementNode *requesterLink = [row awful_firstNodeMatchingCachedSelector:@"td:nth-of-type(5) a"];
            NSURL *URL = [NSURL URLWithString:requesterLink[@"href"]];
            NSString *userID = URL.queryDictionary[@"userid"];
            NSString *username = [requesterLink.innerHTML gtm_stringByUnescapingFromHTML];
            AwfulUser *requester = [AwfulUser firstOrNewUserWithUserID:userID
                                                              username:username
                                                inManagedObjectContext:managedObjectContext];
            if (requester) {
                ban.requester = requester;
            }
        }
        {
            HTMLElementNode *approverLink = [row awful_firstNodeMatchingCachedSelector:@"td:nth-of-type(6) a"];
            NSURL *URL = [NSURL URLWithString:approverLink[@"href"]];
            NSString *userID = URL.queryDictionary[@"userid"];
            NSString *username = [approverLink.innerHTML gtm_stringByUnescapingFromHTML];
            AwfulUser *approver = [AwfulUser firstOrNewUserWithUserID:userID
                                                             username:username
                                               inManagedObjectContext:managedObjectContext];
            if (approver) {
                ban.approver = approver;
            }
        }
        [bans addObject:ban];
    }
    return bans;
}

@end
