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
    static __unsafe_unretained NSString *scriptFilenames[] = {
        @"zepto.min.js",
        @"fastclick.js",
        @"profile.js",
        @"spoilers.js",
    };
    NSMutableArray *scripts = [NSMutableArray new];
    for (NSUInteger i = 0, end = sizeof(scriptFilenames) / sizeof(*scriptFilenames); i < end; i++) {
        NSString *filename = scriptFilenames[i];
        NSURL *URL = [[NSBundle mainBundle] URLForResource:filename withExtension:nil];
        NSError *error;
        NSString *script = [NSString stringWithContentsOfURL:URL encoding:NSUTF8StringEncoding error:&error];
        if (!script) {
            NSLog(@"%s error loading %@ from %@: %@", __PRETTY_FUNCTION__, filename, URL, error);
            return nil;
        }
        [scripts addObject:script];
    }
    return [scripts componentsJoinedByString:@"\n\n"];
}

- (id)valueForUndefinedKey:(NSString *)key
{
    return [self.user valueForKey:key];
}

@end
