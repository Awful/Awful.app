//  AwfulExternalBrowser.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulExternalBrowser.h"

@interface AwfulExternalBrowser ()

@property (copy, nonatomic) NSString *title;

@property (copy, nonatomic) NSString *iconName;

@property (copy, nonatomic) NSString *httpScheme;

@property (copy, nonatomic) NSString *httpsScheme;

@property (copy, nonatomic) NSString *ftpScheme;

@end


@implementation AwfulExternalBrowser

+ (NSArray *)availableBrowserActivities
{
	NSMutableArray *listOfBrowsers = [NSMutableArray new];
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"Browsers" withExtension:@"plist"];
    for (NSDictionary *dict in [NSArray arrayWithContentsOfURL:url]) {
        AwfulExternalBrowser *browser = [AwfulExternalBrowser new];
        browser.title = dict[@"Title"];
		browser.iconName = dict[@"icon"];
        browser.httpScheme = dict[@"http"];
        browser.httpsScheme = dict[@"https"];
        browser.ftpScheme = dict[@"ftp"];
        if ([browser isInstalled]) [listOfBrowsers addObject:browser];
    }
    return listOfBrowsers;
}

- (NSString *)activityType
{
	return [NSString stringWithFormat:@"%@-%@", self.class, self.title];
}

- (NSString *)activityTitle
{
	return [NSString stringWithFormat:@"Open in %@", self.title];
}

- (UIImage *)activityImage
{
	return [UIImage imageNamed:self.iconName] ?: [UIImage imageNamed:@"browser-safari"];
}

+ (UIActivityCategory)activityCategory
{
	return UIActivityCategoryAction;
}


- (BOOL)isInstalled
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://", self.httpScheme]];
    return [[UIApplication sharedApplication] canOpenURL:url];
}


- (void)performActivity
{
	NSString *absoluteString = [self.url absoluteString];
    NSRange colon = [absoluteString rangeOfString:@":"];
    NSString *schemeless = [absoluteString substringFromIndex:colon.location];
    NSString *redirect = [[self adaptedSchemeForURL:self.url] stringByAppendingString:schemeless];
    BOOL completed = [[UIApplication sharedApplication] openURL:[NSURL URLWithString:redirect]];
	
	[self activityDidFinish:completed];
}

- (BOOL)canOpenURL:(NSURL *)url
{
    return !![self adaptedSchemeForURL:url];
}

- (NSString *)adaptedSchemeForURL:(NSURL *)url
{
    NSString *scheme = [[url scheme] lowercaseString];
    if ([scheme isEqualToString:@"http"]) return self.httpScheme;
    if ([scheme isEqualToString:@"https"]) return self.httpsScheme;
    if ([scheme isEqualToString:@"ftp"]) return self.ftpScheme;
    return nil;
}


@end
