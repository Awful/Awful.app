//  AuthorScraper.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AuthorScraper.h"
#import "AwfulCompoundDateParser.h"
#import <AwfulCore/AwfulCore-Swift.h>

@interface AuthorScraper ()

@property (copy, nonatomic) NSString *userID;

@property (copy, nonatomic) NSString *username;

@property (copy, nonatomic) NSDictionary *otherAttributes;

@end

@implementation AuthorScraper

@synthesize author = _author;

- (void)scrape
{
    [super scrape];
    if (self.error) return;
    
    // Posts and PMs have a "Profile" link we can grab. Profiles and ignored posts don't.
    HTMLElement *profileLink = [self.node firstNodeMatchingSelector:@"ul.profilelinks a[href *= 'userid']"];
    if (profileLink) {
        NSURL *URL = [NSURL URLWithString:profileLink[@"href"]];
        self.userID = URL.awful_queryDictionary[@"userid"];
    } else {
        // Ignored posts still put the userid in the td.userinfo.
        NSString *userInfoClass = [self.node firstNodeMatchingSelector:@"td.userinfo"][@"class"];
        if (userInfoClass) {
            NSScanner *scanner = [NSScanner scannerWithString:userInfoClass];
            [scanner scanUpToString:@"userid-" intoString:nil];
            [scanner scanString:@"userid-" intoString:nil];
            NSString *userID;
            if ([scanner scanCharactersFromSet:[NSCharacterSet decimalDigitCharacterSet] intoString:&userID]) {
                self.userID = userID;
            }
        } else {
            HTMLElement *userIDInput = [self.node firstNodeMatchingSelector:@"input[name = 'userid']"];
            self.userID = userIDInput[@"value"];
        }
    }
    HTMLElement *authorTerm = [self.node firstNodeMatchingSelector:@"dt.author"];
    self.username = authorTerm.textContent;
    
    if (self.userID.length == 0 && self.username.length == 0) {
        NSString *message = @"Could not find author's user ID or username";
        self.error = [NSError errorWithDomain:AwfulCoreError.domain code:AwfulCoreError.parseError userInfo:@{ NSLocalizedDescriptionKey: message }];
        return;
    }
    
    NSMutableDictionary *otherAttributes = [NSMutableDictionary new];
    if (authorTerm[@"class"]) {
        otherAttributes[@"administrator"] = @([authorTerm hasClass:@"role-admin"]);
        otherAttributes[@"moderator"] = @([authorTerm hasClass:@"role-mod"]);
		otherAttributes[@"authorClasses"] = authorTerm[@"class"];
    }
    HTMLElement *regdateDefinition = [self.node firstNodeMatchingSelector:@"dd.registered"];
    NSDate *regdate = [RegdateParser() dateFromString:regdateDefinition.innerHTML];
    if (regdate) {
        otherAttributes[@"regdate"] = regdate;
    }
    HTMLElement *customTitleDefinition = [self.node firstNodeMatchingSelector:@"dl.userinfo dd.title"];
    if (customTitleDefinition) {
        HTMLElement *superfluousLineBreak = [customTitleDefinition firstNodeMatchingSelector:@"br.pb"];
        [superfluousLineBreak.parentNode.mutableChildren removeObject:superfluousLineBreak];
        otherAttributes[@"customTitleHTML"] = customTitleDefinition.innerHTML;
    }
    self.otherAttributes = otherAttributes;
}

- (User *)author
{
    if (_author || self.error) return _author;
    UserKey *userKey = [[UserKey alloc] initWithUserID:self.userID username:self.username];
    self.author = [User objectForKey:userKey inManagedObjectContext:self.managedObjectContext];
    return _author;
}

- (void)setAuthor:(User *)author
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
