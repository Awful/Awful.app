//  AwfulLepersColonyPageScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulLepersColonyPageScraper.h"
#import "AwfulCompoundDateParser.h"
#import "GTMNSString+HTML.h"
#import "HTMLNode+CachedSelector.h"
#import "NSURL+QueryDictionary.h"

@interface AwfulLepersColonyPageScraper ()

@property (copy, nonatomic) NSArray *bans;

@end

@implementation AwfulLepersColonyPageScraper

- (void)scrape
{
    NSMutableArray *bans = [NSMutableArray new];
    
    NSEnumerator *rows = [self.node awful_nodesMatchingCachedSelector:@"table.standard tr"].objectEnumerator;
    
    // First row just has headers.
    [rows nextObject];
    
    for (HTMLElement *row in rows) {
        AwfulBan *ban = [AwfulBan new];
        {{
            HTMLElement *typeCell = [row awful_firstNodeMatchingCachedSelector:@"td:nth-of-type(1)"];
            HTMLElement *typeLink = [typeCell awful_firstNodeMatchingCachedSelector:@"a"];
            NSURL *URL = [NSURL URLWithString:typeLink[@"href"]];
            NSString *postID = URL.queryDictionary[@"postid"];
            if (postID) {
                ban.post = [AwfulPost firstOrNewPostWithPostID:postID inManagedObjectContext:self.managedObjectContext];
            }
            
            NSString *typeHTML = typeCell.innerHTML;
            if ([typeHTML rangeOfString:@"PROBATION"].location != NSNotFound) {
                ban.punishment = AwfulPunishmentProbation;
            } else if ([typeHTML rangeOfString:@"PERMABAN"].location != NSNotFound) {
                ban.punishment = AwfulPunishmentPermaban;
            } else if ([typeHTML rangeOfString:@"BAN"].location != NSNotFound) {
                ban.punishment = AwfulPunishmentBan;
            }
        }}
        
        {{
            HTMLElement *dateCell = [row awful_firstNodeMatchingCachedSelector:@"td:nth-of-type(2)"];
            NSDate *date = [BanDateParser() dateFromString:dateCell.innerHTML];
            if (date) {
                ban.date = date;
            }
        }}
        
        {{
            HTMLElement *userLink = [row awful_firstNodeMatchingCachedSelector:@"td:nth-of-type(3) a"];
            NSURL *URL = [NSURL URLWithString:userLink[@"href"]];
            NSString *userID = URL.queryDictionary[@"userid"];
            NSString *username = [userLink.innerHTML gtm_stringByUnescapingFromHTML];
            AwfulUser *user = [AwfulUser firstOrNewUserWithUserID:userID username:username inManagedObjectContext:self.managedObjectContext];
            if (user) {
                ban.user = user;
            }
        }}
        
        {{
            HTMLElement *reasonCell = [row awful_firstNodeMatchingCachedSelector:@"td:nth-of-type(4)"];
            ban.reasonHTML = reasonCell.innerHTML;
        }}
        
        {{
            HTMLElement *requesterLink = [row awful_firstNodeMatchingCachedSelector:@"td:nth-of-type(5) a"];
            NSURL *URL = [NSURL URLWithString:requesterLink[@"href"]];
            NSString *userID = URL.queryDictionary[@"userid"];
            NSString *username = [requesterLink.innerHTML gtm_stringByUnescapingFromHTML];
            AwfulUser *requester = [AwfulUser firstOrNewUserWithUserID:userID username:username inManagedObjectContext:self.managedObjectContext];
            if (requester) {
                ban.requester = requester;
            }
        }}
        
        {{
            HTMLElement *approverLink = [row awful_firstNodeMatchingCachedSelector:@"td:nth-of-type(6) a"];
            NSURL *URL = [NSURL URLWithString:approverLink[@"href"]];
            NSString *userID = URL.queryDictionary[@"userid"];
            NSString *username = [approverLink.innerHTML gtm_stringByUnescapingFromHTML];
            AwfulUser *approver = [AwfulUser firstOrNewUserWithUserID:userID username:username inManagedObjectContext:self.managedObjectContext];
            if (approver) {
                ban.approver = approver;
            }
        }}
        
        [bans addObject:ban];
    }
    self.bans = bans;
}

static AwfulCompoundDateParser * BanDateParser(void)
{
    static AwfulCompoundDateParser *parser;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        parser = [[AwfulCompoundDateParser alloc] initWithFormats:@[ @"MM/dd/yy hh:mma" ]];
    });
    return parser;
}

@end
