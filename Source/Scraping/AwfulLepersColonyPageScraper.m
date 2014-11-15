//  AwfulLepersColonyPageScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulLepersColonyPageScraper.h"
#import "AwfulBan.h"
#import "AwfulCompoundDateParser.h"
#import "AwfulErrorDomain.h"
#import "AwfulFrameworkCategories.h"
#import "HTMLNode+CachedSelector.h"
#import "Awful-Swift.h"

@interface AwfulLepersColonyPageScraper ()

@property (copy, nonatomic) NSArray *bans;

@end

@implementation AwfulLepersColonyPageScraper

- (void)scrape
{
    [super scrape];
    if (self.error) return;
    
    NSMutableArray *bans = [NSMutableArray new];
    NSMutableArray *rows = [[self.node awful_nodesMatchingCachedSelector:@"table.standard tr"] mutableCopy];
    if (rows.count == 0) {
        self.error = [NSError errorWithDomain:AwfulErrorDomain code:AwfulErrorCodes.parseError userInfo:@{ NSLocalizedDescriptionKey: @"Could not find table rows" }];
        return;
    }
    
    // First row just has headers.
    [rows removeObjectAtIndex:0];
    
    // Find all the post IDs and user IDs/names so we can fetch the ones we know about. Then we'll come back around and update/insert as needed.
    NSMutableArray *infoDictionaries = [NSMutableArray new];
    NSMutableArray *postKeys = [NSMutableArray new];
    NSMutableArray *userKeys = [NSMutableArray new];
    for (HTMLElement *row in rows) {
        NSMutableDictionary *info = [NSMutableDictionary new];
        HTMLElement *typeCell = [row awful_firstNodeMatchingCachedSelector:@"td:nth-of-type(1)"];
        
        {{
            HTMLElement *typeLink = [typeCell awful_firstNodeMatchingCachedSelector:@"a"];
            NSURL *URL = [NSURL URLWithString:typeLink[@"href"]];
            NSString *postID = URL.queryDictionary[@"postid"];
            if (postID.length > 0) {
                PostKey *postKey = [[PostKey alloc] initWithPostID:postID];
                info[@"postKey"] = postKey;
                [postKeys addObject:postKey];
            }
        }}
        
        {{
            NSString *typeText = typeCell.textContent;
            if ([typeText rangeOfString:@"PROBATION"].location != NSNotFound) {
                info[@"punishment"] = @(AwfulPunishmentProbation);
            } else if ([typeText rangeOfString:@"PERMABAN"].location != NSNotFound) {
                info[@"punishment"] = @(AwfulPunishmentPermaban);
            } else if ([typeText rangeOfString:@"BAN"].location != NSNotFound) {
                info[@"punishment"] = @(AwfulPunishmentBan);
            }
        }}
        
        {{
            HTMLElement *userLink = [row awful_firstNodeMatchingCachedSelector:@"td:nth-of-type(3) a"];
            NSURL *URL = [NSURL URLWithString:userLink[@"href"]];
            NSString *userID = URL.queryDictionary[@"userid"];
            NSString *username = userLink.textContent;
            if (userID.length > 0 || username.length > 0) {
                UserKey *userKey = [[UserKey alloc] initWithUserID:userID username:username];
                info[@"userKey"] = userKey;
                [userKeys addObject:userKey];
            }
        }}
        
        {{
            HTMLElement *requesterLink = [row awful_firstNodeMatchingCachedSelector:@"td:nth-of-type(5) a"];
            NSURL *URL = [NSURL URLWithString:requesterLink[@"href"]];
            NSString *userID = URL.queryDictionary[@"userid"];
            NSString *username = requesterLink.textContent;
            if (userID.length > 0 || username.length > 0) {
                UserKey *userKey = [[UserKey alloc] initWithUserID:userID username:username];
                info[@"requesterUserKey"] = userKey;
                [userKeys addObject:userKey];
            }
        }}
        
        {{
            HTMLElement *approverLink = [row awful_firstNodeMatchingCachedSelector:@"td:nth-of-type(6) a"];
            NSURL *URL = [NSURL URLWithString:approverLink[@"href"]];
            NSString *userID = URL.queryDictionary[@"userid"];
            NSString *username = approverLink.textContent;
            if (userID.length > 0 || username.length > 0) {
                UserKey *userKey = [[UserKey alloc] initWithUserID:userID username:username];
                info[@"approverUserKey"] = userKey;
                [userKeys addObject:userKey];
            }
        }}
        
        [infoDictionaries addObject:info];
    }
    NSArray *posts = [Post objectsForKeys:postKeys inManagedObjectContext:self.managedObjectContext];
    NSDictionary *postsByKey = [NSDictionary dictionaryWithObjects:posts forKeys:[posts valueForKey:@"objectKey"]];
    NSArray *users = [User objectsForKeys:userKeys inManagedObjectContext:self.managedObjectContext];
    NSDictionary *usersByKey = [NSDictionary dictionaryWithObjects:users forKeys:[users valueForKey:@"objectKey"]];
    
    [rows enumerateObjectsUsingBlock:^(HTMLElement *row, NSUInteger i, BOOL *stop) {
        AwfulBan *ban = [AwfulBan new];
        NSDictionary *info = infoDictionaries[i];
        
        {{
            PostKey *postKey = info[@"postKey"];
            if (postKey) {
                ban.post = postsByKey[postKey];
            }
        }}
        
        {{
            UserKey *userKey = info[@"userKey"];
            if (userKey) {
                ban.user = usersByKey[userKey];
            }
        }}
        
        ban.punishment = [info[@"punishment"] integerValue];
        
        {{
            HTMLElement *dateCell = [row awful_firstNodeMatchingCachedSelector:@"td:nth-of-type(2)"];
            NSDate *date = [BanDateParser() dateFromString:dateCell.innerHTML];
            if (date) {
                ban.date = date;
            }
        }}
        
        {{
            HTMLElement *reasonCell = [row awful_firstNodeMatchingCachedSelector:@"td:nth-of-type(4)"];
            ban.reasonHTML = reasonCell.textContent;
        }}
        
        {{
            UserKey *requesterKey = info[@"requesterUserKey"];
            if (requesterKey) {
                ban.requester = usersByKey[requesterKey];
            }
        }}
        
        {{
            UserKey *approverKey = info[@"requesterUserKey"];
            if (approverKey) {
                ban.approver = usersByKey[approverKey];
            }
        }}
        
        [bans addObject:ban];
    }];
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
