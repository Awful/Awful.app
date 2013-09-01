//
//  AwfulExternalBrowser.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app
//

#import "AwfulExternalBrowser.h"

@interface AwfulExternalBrowser ()

@property (copy, nonatomic) NSString *title;

@property (copy, nonatomic) NSString *httpScheme;

@property (copy, nonatomic) NSString *httpsScheme;

@property (copy, nonatomic) NSString *ftpScheme;

@end

@implementation AwfulExternalBrowser

+ (NSArray *)installedBrowsers
{
    NSMutableArray *listOfBrowsers = [NSMutableArray new];
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"Browsers" withExtension:@"plist"];
    for (NSDictionary *dict in [NSArray arrayWithContentsOfURL:url]) {
        AwfulExternalBrowser *browser = [AwfulExternalBrowser new];
        browser.title = dict[@"Title"];
        browser.httpScheme = dict[@"http"];
        browser.httpsScheme = dict[@"https"];
        browser.ftpScheme = dict[@"ftp"];
        if ([browser isInstalled]) [listOfBrowsers addObject:browser];
    }
    return listOfBrowsers;
}

- (BOOL)isInstalled
{
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://", self.httpScheme]];
    return [[UIApplication sharedApplication] canOpenURL:url];
}

- (void)openURL:(NSURL *)url
{
    NSString *absoluteString = [url absoluteString];
    NSRange colon = [absoluteString rangeOfString:@":"];
    NSString *schemeless = [absoluteString substringFromIndex:colon.location];
    NSString *redirect = [[self adaptedSchemeForURL:url] stringByAppendingString:schemeless];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:redirect]];
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
