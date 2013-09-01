//  UIDevice+OperatingSystemVersion.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIDevice+OperatingSystemVersion.h"

@implementation UIDevice (OperatingSystemVersion)

- (BOOL)awful_iOS5
{
    NSString *systemVersion = self.systemVersion;
    if ([systemVersion compare:@"5.0" options:NSNumericSearch] == NSOrderedAscending) return NO;
    return [systemVersion compare:@"6.0" options:NSNumericSearch] == NSOrderedAscending;
}

- (BOOL)awful_iOS6OrLater
{
    NSString *systemVersion = self.systemVersion;
    return [systemVersion compare:@"6.0" options:NSNumericSearch] != NSOrderedAscending;
}

@end
