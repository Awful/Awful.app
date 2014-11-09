//  AwfulProfileViewModel.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulProfileViewModel.h"
#import "AwfulSettings.h"
#import "Awful-Swift.h"

@interface AwfulProfileViewModel ()

@property (nonatomic) User *user;

@end

@implementation AwfulProfileViewModel

- (instancetype)initWithUser:(User *)user
{
    if ((self = [super init])) {
        _user = user;
    }
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
    return [AwfulSettings sharedSettings].darkTheme;
}

- (NSDateFormatter *)regDateFormat
{
    return [NSDateFormatter regDateFormatter];
}

- (NSDateFormatter *)lastPostDateFormat
{
	return [NSDateFormatter postDateFormatter];
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
    return self.user.canReceivePrivateMessages && [AwfulSettings sharedSettings].canSendPrivateMessages;
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

- (id)valueForUndefinedKey:(NSString *)key
{
    return [self.user valueForKey:key];
}

@dynamic aboutMe;
@dynamic aimName;
@dynamic avatarURL;
@dynamic homepageURL;
@dynamic icqName;
@dynamic interests;
@dynamic lastPost;
@dynamic location;
@dynamic occupation;
@dynamic postCount;
@dynamic postRate;
@dynamic profilePictureURL;
@dynamic regdate;
@dynamic username;
@dynamic yahooName;

@end
