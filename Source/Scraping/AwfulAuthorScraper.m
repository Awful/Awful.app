//  AwfulAuthorScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulAuthorScraper.h"
#import "AwfulCompoundDateParser.h"
#import "AwfulErrorDomain.h"
#import "HTMLNode+CachedSelector.h"
#import "NSURL+QueryDictionary.h"

@interface AwfulAuthorScraper ()

@property (copy, nonatomic) NSString *userID;

@property (copy, nonatomic) NSString *username;

@property (copy, nonatomic) NSDictionary *otherAttributes;

@end

@implementation AwfulAuthorScraper

@synthesize author = _author;

- (void)scrape
{
    // Posts and PMs have a "Profile" link we can grab. Profiles, unsurprisingly, don't.
    HTMLElement *profileLink = [self.node awful_firstNodeMatchingCachedSelector:@"ul.profilelinks a[href *= 'userid']"];
    if (profileLink) {
        NSURL *URL = [NSURL URLWithString:profileLink[@"href"]];
        self.userID = URL.queryDictionary[@"userid"];
    } else {
        HTMLElement *userIDInput = [self.node awful_firstNodeMatchingCachedSelector:@"input[name = 'userid']"];
        self.userID = userIDInput[@"value"];
    }
    HTMLElement *authorTerm = [self.node awful_firstNodeMatchingCachedSelector:@"dt.author"];
    self.username = authorTerm.textContent;
    
    if (self.userID.length == 0 && self.username.length == 0) {
        NSString *message = @"Could not find author's user ID or username";
        self.error = [NSError errorWithDomain:AwfulErrorDomain code:AwfulErrorCodes.parseError userInfo:@{ NSLocalizedDescriptionKey: message }];
        return;
    }
    
    NSMutableDictionary *otherAttributes = [NSMutableDictionary new];
    if (authorTerm[@"class"]) {
        otherAttributes[@"administrator"] = @([authorTerm hasClass:@"role-admin"]);
        otherAttributes[@"moderator"] = @([authorTerm hasClass:@"role-mod"]);
        otherAttributes[@"idiotKing"] = @([authorTerm hasClass:@"role-ik"]);
    }
    HTMLElement *regdateDefinition = [self.node awful_firstNodeMatchingCachedSelector:@"dd.registered"];
    NSDate *regdate = [RegdateParser() dateFromString:regdateDefinition.innerHTML];
    if (regdate) {
        otherAttributes[@"regdate"] = regdate;
    }
    HTMLElement *customTitleDefinition = [self.node awful_firstNodeMatchingCachedSelector:@"dl.userinfo dd.title"];
    if (customTitleDefinition) {
        otherAttributes[@"customTitleHTML"] = customTitleDefinition.innerHTML;
    }
    self.otherAttributes = otherAttributes;
}

- (AwfulUser *)author
{
    if (_author || self.error) return _author;
    self.author = [AwfulUser firstOrNewUserWithUserID:self.userID username:self.username inManagedObjectContext:self.managedObjectContext];
    return _author;
}

- (void)setAuthor:(AwfulUser *)author
{
    _author = author;
    [author setValuesForKeysWithDictionary:_otherAttributes];
    if (self.userID.length > 0 && author.userID.length == 0) {
        author.userID = self.userID;
    }
    if (self.username.length > 0) {
        author.username = self.username;
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
