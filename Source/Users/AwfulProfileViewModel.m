//  AwfulProfileViewModel.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulProfileViewModel.h"
#import "AwfulDateFormatters.h"
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
    return [contactInfo.allValues indexOfObjectPassingTest:^BOOL(NSString *string, NSUInteger i, BOOL *stop) {
        return (![[NSNull null] isEqual:string] && string.length > 0);
    }] != NSNotFound;
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

- (NSString *)JavaScriptLibraries
{
    NSURL *URLForZepto = [[NSBundle mainBundle] URLForResource:@"zepto.min" withExtension:@"js"];
    NSError *error;
    NSString *zepto = [NSString stringWithContentsOfURL:URLForZepto encoding:NSUTF8StringEncoding error:&error];
    if (!zepto) {
        NSLog(@"%s error loading zepto.js from %@: %@", __PRETTY_FUNCTION__, URLForZepto, error);
    }
    
    NSURL *URLForFastClick = [[NSBundle mainBundle] URLForResource:@"fastclick" withExtension:@"js"];
    NSString *fastClick = [NSString stringWithContentsOfURL:URLForFastClick encoding:NSUTF8StringEncoding error:&error];
    if (!fastClick) {
        NSLog(@"%s error loading fastclick.js from %@: %@", __PRETTY_FUNCTION__, URLForFastClick, error);
    }
    
    return [NSString stringWithFormat:@"%@\n%@", zepto, fastClick];
}

- (id)valueForUndefinedKey:(NSString *)key
{
    return [self.user valueForKey:key];
}

@end
