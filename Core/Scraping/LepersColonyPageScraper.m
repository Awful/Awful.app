//  LepersColonyPageScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "LepersColonyPageScraper.h"
#import "AwfulCompoundDateParser.h"
#import "NSURLQueryDictionary.h"
#import <AwfulCore/AwfulCore-Swift.h>

@interface LepersColonyPageScraper ()

@property (copy, nonatomic) NSArray *punishments;

@end

@implementation LepersColonyPageScraper

- (void)scrape
{
    [super scrape];
    if (self.error) return;
    
    NSMutableArray *punishments = [NSMutableArray new];
    NSMutableArray *rows = [[self.node nodesMatchingSelector:@"table.standard tr"] mutableCopy];
    if (rows.count == 0) {
        self.error = [NSError errorWithDomain:AwfulCoreError.domain code:AwfulCoreError.parseError userInfo:@{ NSLocalizedDescriptionKey: @"Could not find table rows" }];
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
        HTMLElement *typeCell = [row firstNodeMatchingSelector:@"td:nth-of-type(1)"];
        
        {{
            HTMLElement *typeLink = [typeCell firstNodeMatchingSelector:@"a"];
            NSURL *URL = [NSURL URLWithString:typeLink[@"href"]];
            NSString *postID = AwfulCoreQueryDictionaryWithURL(URL)[@"postid"];
            if (postID.length > 0) {
                PostKey *postKey = [[PostKey alloc] initWithPostID:postID];
                info[@"postKey"] = postKey;
                [postKeys addObject:postKey];
            }
        }}
        
        {{
            NSString *typeText = typeCell.textContent;
            if ([typeText rangeOfString:@"PROBATION"].location != NSNotFound) {
                info[@"sentence"] = @(PunishmentSentenceProbation);
            } else if ([typeText rangeOfString:@"PERMABAN"].location != NSNotFound) {
                info[@"sentence"] = @(PunishmentSentencePermaban);
            } else if ([typeText rangeOfString:@"BAN"].location != NSNotFound) {
                info[@"sentence"] = @(PunishmentSentenceBan);
            }
        }}
        
        {{
            HTMLElement *userLink = [row firstNodeMatchingSelector:@"td:nth-of-type(3) a"];
            NSURL *URL = [NSURL URLWithString:userLink[@"href"]];
            NSString *userID = AwfulCoreQueryDictionaryWithURL(URL)[@"userid"];
            NSString *username = userLink.textContent;
            if (userID.length > 0 || username.length > 0) {
                UserKey *userKey = [[UserKey alloc] initWithUserID:userID username:username];
                info[@"subjectUserKey"] = userKey;
                [userKeys addObject:userKey];
            }
        }}
        
        {{
            HTMLElement *requesterLink = [row firstNodeMatchingSelector:@"td:nth-of-type(5) a"];
            NSURL *URL = [NSURL URLWithString:requesterLink[@"href"]];
            NSString *userID = AwfulCoreQueryDictionaryWithURL(URL)[@"userid"];
            NSString *username = requesterLink.textContent;
            if (userID.length > 0 || username.length > 0) {
                UserKey *userKey = [[UserKey alloc] initWithUserID:userID username:username];
                info[@"requesterUserKey"] = userKey;
                [userKeys addObject:userKey];
            }
        }}
        
        {{
            HTMLElement *approverLink = [row firstNodeMatchingSelector:@"td:nth-of-type(6) a"];
            NSURL *URL = [NSURL URLWithString:approverLink[@"href"]];
            NSString *userID = AwfulCoreQueryDictionaryWithURL(URL)[@"userid"];
            NSString *username = approverLink.textContent;
            if (userID.length > 0 || username.length > 0) {
                UserKey *userKey = [[UserKey alloc] initWithUserID:userID username:username];
                info[@"approverUserKey"] = userKey;
                [userKeys addObject:userKey];
            }
        }}
        
        [infoDictionaries addObject:info];
    }

    if (postKeys.count == 0)
        return;

    NSArray *posts = [Post objectsForKeys:postKeys inManagedObjectContext:self.managedObjectContext];
    NSDictionary *postsByKey = [NSDictionary dictionaryWithObjects:posts forKeys:[posts valueForKey:@"objectKey"]];
    NSArray *users = [User objectsForKeys:userKeys inManagedObjectContext:self.managedObjectContext];
    NSDictionary *usersByKey = [NSDictionary dictionaryWithObjects:users forKeys:[users valueForKey:@"objectKey"]];
    
    [rows enumerateObjectsUsingBlock:^(HTMLElement *row, NSUInteger i, BOOL *stop) {
        NSDictionary *info = infoDictionaries[i];
        Punishment *punishment;
        {{
            HTMLElement *dateCell = [row firstNodeMatchingSelector:@"td:nth-of-type(2)"];
            NSDate *date = [DateParser() dateFromString:dateCell.textContent];
            PunishmentSentence sentence = [info[@"sentence"] integerValue];
            User *subject;
            UserKey *userKey = info[@"subjectUserKey"];
            if (userKey) {
                subject = usersByKey[userKey];
            }
            
            if (date && subject) {
                punishment = [[Punishment alloc] initWithDate:date sentence:sentence subject:subject];
            } else {
                return;
            }
        }}

        {{
            PostKey *postKey = info[@"postKey"];
            if (postKey) {
                punishment.post = postsByKey[postKey];
            }
        }}
        
        {{
            HTMLElement *reasonCell = [row firstNodeMatchingSelector:@"td:nth-of-type(4)"];
            punishment.reasonHTML = reasonCell.textContent;
        }}
        
        {{
            UserKey *requesterKey = info[@"requesterUserKey"];
            if (requesterKey) {
                punishment.requester = usersByKey[requesterKey];
            }
        }}
        
        {{
            UserKey *approverKey = info[@"requesterUserKey"];
            if (approverKey) {
                punishment.approver = usersByKey[approverKey];
            }
        }}
        
        [punishments addObject:punishment];
    }];
    self.punishments = punishments;
}

static AwfulCompoundDateParser * DateParser(void)
{
    static AwfulCompoundDateParser *parser;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        parser = [[AwfulCompoundDateParser alloc] initWithFormats:@[ @"MM/dd/yy hh:mma" ]];
    });
    return parser;
}

@end
