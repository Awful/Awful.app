//
//  NSURL+OpensInBrowser.m
//  Awful
//
//  Created by Nolan Waite on 2012-12-19.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "NSURL+OpensInBrowser.h"

@implementation NSURL (OpensInBrowser)

- (BOOL)opensInBrowser
{
    NSString *scheme = [[self scheme] lowercaseString];
    if (!([scheme hasPrefix:@"http"] || [scheme isEqualToString:@"ftp"])) return NO;
    NSString *host = [[self host] lowercaseString];
    if ([host hasSuffix:@"itunes.apple.com"]) return NO;
    if ([host hasSuffix:@"phobos.apple.com"]) return NO;
    NSComparisonResult atLeastSix = [[UIDevice currentDevice].systemVersion
                                     compare:@"6.0" options:NSNumericSearch];
    if (atLeastSix == NSOrderedAscending) {
        if ([host hasSuffix:@"www.youtube.com"]) return NO;
    }
    return YES;
}

@end
