//
//  NSURL+OpensInBrowser.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "NSURL+OpensInBrowser.h"
#import "UIDevice+OperatingSystemVersion.h"

@implementation NSURL (OpensInBrowser)

- (BOOL)opensInBrowser
{
    NSString *scheme = [[self scheme] lowercaseString];
    if (!([scheme hasPrefix:@"http"] || [scheme isEqualToString:@"ftp"])) return NO;
    NSString *host = [[self host] lowercaseString];
    if ([host hasSuffix:@"itunes.apple.com"]) return NO;
    if ([host hasSuffix:@"phobos.apple.com"]) return NO;
    if ([[UIDevice currentDevice] awful_iOS6OrLater]) {
        if ([host hasSuffix:@"www.youtube.com"]) return NO;
    }
    return YES;
}

@end
