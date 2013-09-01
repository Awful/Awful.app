//  NSURL+OpensInBrowser.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "NSURL+OpensInBrowser.h"

@implementation NSURL (OpensInBrowser)

- (BOOL)opensInBrowser
{
    NSString *scheme = [[self scheme] lowercaseString];
    if (!([scheme hasPrefix:@"http"] || [scheme isEqualToString:@"ftp"])) return NO;
    NSString *host = [[self host] lowercaseString];
    if ([host hasSuffix:@"itunes.apple.com"]) return NO;
    if ([host hasSuffix:@"phobos.apple.com"]) return NO;
    return YES;
}

@end
