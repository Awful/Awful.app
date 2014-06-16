//  AwfulLepersColonyPageScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulLepersColonyPageScraper.h"
#import "AwfulCompoundDateParser.h"
#import "AwfulErrorDomain.h"
#import "AwfulFrameworkCategories.h"
#import "HTMLNode+CachedSelector.h"

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
    NSMutableArray *postIDs = [NSMutableArray new];
    NSMutableArray *userIDs = [NSMutableArray new];
    NSMutableArray *usernames = [NSMutableArray new];
    for (HTMLElement *row in rows) {
        NSMutableDictionary *info = [NSMutableDictionary new];
        HTMLElement *typeCell = [row awful_firstNodeMatchingCachedSelector:@"td:nth-of-type(1)"];
        
        {{
            HTMLElement *typeLink = [typeCell awful_firstNodeMatchingCachedSelector:@"a"];
            NSURL *URL = [NSURL URLWithString:typeLink[@"href"]];
            NSString *postID = URL.queryDictionary[@"postid"];
            if (postID.length > 0) {
                info[@"postID"] = postID;
                [postIDs addObject:postID];
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
            if (userID.length > 0) {
                [userIDs addObject:userID];
                info[@"userID"] = userID;
            }
            NSString *username = userLink.textContent;
            if (username.length > 0) {
                [usernames addObject:username];
                info[@"username"] = username;
            }
        }}
        
        {{
            HTMLElement *requesterLink = [row awful_firstNodeMatchingCachedSelector:@"td:nth-of-type(5) a"];
            NSURL *URL = [NSURL URLWithString:requesterLink[@"href"]];
            NSString *userID = URL.queryDictionary[@"userid"];
            if (userID.length > 0) {
                [userIDs addObject:userID];
                info[@"requesterUserID"] = userID;
            }
            NSString *username = requesterLink.textContent;
            if (username.length > 0) {
                [usernames addObject:username];
                info[@"requesterUsername"] = username;
            }
        }}
        
        {{
            HTMLElement *approverLink = [row awful_firstNodeMatchingCachedSelector:@"td:nth-of-type(6) a"];
            NSURL *URL = [NSURL URLWithString:approverLink[@"href"]];
            NSString *userID = URL.queryDictionary[@"userid"];
            if (userID.length > 0) {
                [userIDs addObject:userID];
                info[@"approverUserID"] = userID;
            }
            NSString *username = approverLink.textContent;
            if (username.length > 0) {
                [usernames addObject:username];
                info[@"approverUsername"] = username;
            }
        }}
        
        [infoDictionaries addObject:info];
    }
    NSMutableDictionary *posts = [[AwfulPost dictionaryOfAllInManagedObjectContext:self.managedObjectContext
                                                             keyedByAttributeNamed:@"postID"
                                                           matchingPredicateFormat:@"postID IN %@", postIDs] mutableCopy];
    NSMutableDictionary *usersByID = [[AwfulUser dictionaryOfAllInManagedObjectContext:self.managedObjectContext
                                                                 keyedByAttributeNamed:@"userID"
                                                               matchingPredicateFormat:@"userID IN %@", userIDs] mutableCopy];
    NSMutableDictionary *usersByName = [[AwfulUser dictionaryOfAllInManagedObjectContext:self.managedObjectContext
                                                                   keyedByAttributeNamed:@"username"
                                                                 matchingPredicateFormat:@"userID = nil AND username IN %@", usernames] mutableCopy];
    
    [rows enumerateObjectsUsingBlock:^(HTMLElement *row, NSUInteger i, BOOL *stop) {
        AwfulBan *ban = [AwfulBan new];
        NSDictionary *info = infoDictionaries[i];
        
        {{
            NSString *postID = info[@"postID"];
            if (postID) {
                AwfulPost *post = posts[postID];
                if (!post) {
                    post = [AwfulPost insertInManagedObjectContext:self.managedObjectContext];
                    post.postID = postID;
                    posts[postID] = post;
                }
                ban.post = post;
            }
        }}
        
        {{
            NSString *userID = info[@"userID"];
            NSString *username = info[@"username"];
            if (userID || username) {
                AwfulUser *user;
                if (userID) {
                    user = usersByID[userID];
                } else {
                    user = usersByName[username];
                }
                if (!user) {
                    user = [AwfulUser insertInManagedObjectContext:self.managedObjectContext];
                }
                if (userID) {
                    user.userID = userID;
                    usersByID[userID] = user;
                }
                if (username) {
                    user.username = username;
                    usersByName[username] = user;
                }
                ban.user = user;
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
            NSString *userID = info[@"requesterUserID"];
            NSString *username = info[@"requesterUsername"];
            if (userID || username) {
                AwfulUser *user;
                if (userID) {
                    user = usersByID[userID];
                } else {
                    user = usersByName[username];
                }
                if (!user) {
                    user = [AwfulUser insertInManagedObjectContext:self.managedObjectContext];
                }
                if (userID) {
                    user.userID = userID;
                    usersByID[userID] = user;
                }
                if (username) {
                    user.username = username;
                    usersByName[username] = user;
                }
                ban.requester = user;
            }
        }}
        
        {{
            NSString *userID = info[@"approverUserID"];
            NSString *username = info[@"approverUsername"];
            if (userID || username) {
                AwfulUser *user;
                if (userID) {
                    user = usersByID[userID];
                } else {
                    user = usersByName[username];
                }
                if (!user) {
                    user = [AwfulUser insertInManagedObjectContext:self.managedObjectContext];
                }
                if (userID) {
                    user.userID = userID;
                    usersByID[userID] = user;
                }
                if (username) {
                    user.username = username;
                    usersByName[username] = user;
                }
                ban.approver = user;
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
