//  AwfulAuthorScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulAuthorScraper.h"
#import "AwfulCompoundDateParser.h"
#import "GTMNSString+HTML.h"
#import "HTMLNode+CachedSelector.h"
#import "NSURL+QueryDictionary.h"

@interface AwfulAuthorScraper ()

@property (strong, nonatomic) AwfulCompoundDateParser *regdateDateParser;

@end

@implementation AwfulAuthorScraper

- (AwfulCompoundDateParser *)regdateDateParser
{
    if (!_regdateDateParser) {
        _regdateDateParser = [[AwfulCompoundDateParser alloc] initWithFormats:@[ @"MMM d, yyyy" ]];
    }
    return _regdateDateParser;
}

- (AwfulUser *)scrapeAuthorFromNode:(HTMLNode *)node
           intoManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
    NSString *userID; {
        HTMLElementNode *profileLink = [node awful_firstNodeMatchingCachedSelector:@"ul.profilelinks a[href *= 'userid']"];
        
        // Posts and PMs have a "Profile" link we can grab. Profiles, unsurprisingly, don't.
        if (profileLink) {
            NSURL *URL = [NSURL URLWithString:profileLink[@"href"]];
            userID = URL.queryDictionary[@"userid"];
        } else {
            HTMLElementNode *userIDInput = [node awful_firstNodeMatchingCachedSelector:@"input[name = 'userid']"];
            userID = userIDInput[@"value"];
        }
    }
    HTMLElementNode *authorTerm = [node awful_firstNodeMatchingCachedSelector:@"dt.author"];
    NSString *username = [authorTerm.innerHTML gtm_stringByUnescapingFromHTML];
    if (userID.length == 0 && username.length == 0) {
        return nil;
    }
    AwfulUser *user = [AwfulUser firstOrNewUserWithUserID:userID
                                                 username:username
                                   inManagedObjectContext:managedObjectContext];
    if (authorTerm[@"class"]) {
        user.administrator = !![authorTerm awful_firstNodeMatchingCachedSelector:@".role-admin"];
			user.moderator = !![authorTerm awful_firstNodeMatchingCachedSelector:@".role-mod"];
			user.idiotKing = !![authorTerm awful_firstNodeMatchingCachedSelector:@".role-ik"];
    }
    NSDate *regdate; {
        HTMLElementNode *regdateDefinition = [node awful_firstNodeMatchingCachedSelector:@"dd.registered"];
        regdate = [self.regdateDateParser dateFromString:regdateDefinition.innerHTML];
    }
    if (regdate) {
        user.regdate = regdate;
    }
    HTMLElementNode *customTitleDefinition = [node awful_firstNodeMatchingCachedSelector:@"dl.userinfo dd.title"];
    if (customTitleDefinition) {
        user.customTitleHTML = customTitleDefinition.innerHTML;
    }
    return user;
}

@end
