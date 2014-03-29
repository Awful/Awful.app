//  AwfulAuthorScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulAuthorScraper.h"
#import "AwfulCompoundDateParser.h"
#import "AwfulErrorDomain.h"
#import "GTMNSString+HTML.h"
#import "HTMLNode+CachedSelector.h"
#import "NSURL+QueryDictionary.h"

@interface AwfulAuthorScraper ()

@property (strong, nonatomic) AwfulUser *author;

@end

@implementation AwfulAuthorScraper

- (void)scrape
{
    NSString *userID;
    
    // Posts and PMs have a "Profile" link we can grab. Profiles, unsurprisingly, don't.
    HTMLElement *profileLink = [self.node awful_firstNodeMatchingCachedSelector:@"ul.profilelinks a[href *= 'userid']"];
    if (profileLink) {
        NSURL *URL = [NSURL URLWithString:profileLink[@"href"]];
        userID = URL.queryDictionary[@"userid"];
    } else {
        HTMLElement *userIDInput = [self.node awful_firstNodeMatchingCachedSelector:@"input[name = 'userid']"];
        userID = userIDInput[@"value"];
    }
    HTMLElement *authorTerm = [self.node awful_firstNodeMatchingCachedSelector:@"dt.author"];
    NSString *username = [authorTerm.innerHTML gtm_stringByUnescapingFromHTML];
    
    if (userID.length == 0 && username.length == 0) {
        NSString *message = @"Could not find author's user ID or username";
        self.error = [NSError errorWithDomain:AwfulErrorDomain code:AwfulErrorCodes.parseError userInfo:@{ NSLocalizedDescriptionKey: message }];
        return;
    }
    
    self.author = [AwfulUser firstOrNewUserWithUserID:userID username:username inManagedObjectContext:self.managedObjectContext];
    if (authorTerm[@"class"]) {
        self.author.administrator = [authorTerm hasClass:@"role-admin"];
        self.author.moderator = [authorTerm hasClass:@"role-mod"];
        self.author.idiotKing = [authorTerm hasClass:@"role-ik"];
    }
    HTMLElement *regdateDefinition = [self.node awful_firstNodeMatchingCachedSelector:@"dd.registered"];
    NSDate *regdate = [RegdateParser() dateFromString:regdateDefinition.innerHTML];
    if (regdate) {
        self.author.regdate = regdate;
    }
    HTMLElement *customTitleDefinition = [self.node awful_firstNodeMatchingCachedSelector:@"dl.userinfo dd.title"];
    if (customTitleDefinition) {
        self.author.customTitleHTML = customTitleDefinition.innerHTML;
    }
}

static AwfulCompoundDateParser * RegdateParser(void)
{
    static AwfulCompoundDateParser *parser;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        parser = [[AwfulCompoundDateParser alloc] initWithFormats:@[ @"MMM d, yyyy" ]];
    });
    return parser;
}

@end
