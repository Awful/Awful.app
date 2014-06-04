//  AwfulProfileViewModel.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulProfileViewModel.h"
#import "AwfulDateFormatters.h"
#import "AwfulJavaScript.h"
#import "AwfulSettings.h"

@interface AwfulProfileViewModel ()

@property (nonatomic) AwfulUser *user;

@end

@implementation AwfulProfileViewModel

- (id)initWithUser:(AwfulUser *)user
{
    self = [super init];
    if (!self) return nil;
    
    _user = user;
    
    return self;
}

- (NSString *)stylesheet
{
    NSURL *URL = [[NSBundle mainBundle] URLForResource:@"profile" withExtension:@"css"];
    NSError *error;
    NSString *stylesheet = [NSString stringWithContentsOfURL:URL encoding:NSUTF8StringEncoding error:&error];
    if (!stylesheet) {
        NSLog(@"%s error loading stylesheet from %@: %@", __PRETTY_FUNCTION__, URL, error);
    }
    return stylesheet;
}

- (NSString *)userInterfaceIdiom
{
    return UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad ? @"ipad" : @"iphone";
}

- (BOOL)dark
{
    return [AwfulSettings settings].darkTheme;
}

- (NSDateFormatter *)regDateFormat
{
    return [AwfulDateFormatters regDateFormatter];
}

- (NSDateFormatter *)lastPostDateFormat
{
	return [AwfulDateFormatters postDateFormatter];
}

- (BOOL)anyContactInfo
{
    if (self.privateMessagesWork) return YES;
    NSDictionary *contactInfo = [self.user dictionaryWithValuesForKeys:@[ @"aimName", @"icqName", @"yahooName", @"homepageURL" ]];
    for (id value in contactInfo.allValues) {
        if ([value respondsToSelector:@selector(length)] && [value length] > 0) return YES;
        if ([value respondsToSelector:@selector(absoluteString)] && [value absoluteString].length > 0) return YES;
    }
    return NO;
}

- (BOOL)privateMessagesWork
{
    return self.user.canReceivePrivateMessages && [AwfulSettings settings].canSendPrivateMessages;
}

- (NSString *)customTitleHTML
{
    NSString *HTML = self.user.customTitleHTML;
    return [HTML isEqualToString:@"<br/>"] ? nil : HTML;
}

- (NSString *)gender
{
    return self.user.gender ?: @"porpoise";
}

- (NSString *)javascript
{
    NSError *error;
    NSString *script = LoadJavaScriptResources(@[ @"zepto.min.js", @"common.js", @"profile.js" ], &error);
    if (!script) {
        NSLog(@"%s error loading scripts: %@", __PRETTY_FUNCTION__, error);
    }
    return script;
}

- (id)valueForUndefinedKey:(NSString *)key
{
    return [self.user valueForKey:key];
}

@end
