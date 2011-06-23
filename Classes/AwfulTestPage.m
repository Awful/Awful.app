//
//  AwfulTestPage.m
//  Awful
//
//  Created by Regular Berry on 6/22/11.
//  Copyright 2011 Regular Berry Software LLC. All rights reserved.
//

#import "AwfulTestPage.h"
#import "AwfulPageRefreshRequest.h"
#import "AwfulNavigator.h"

@implementation AwfulTestPage

-(NSString *)getURLSuffix
{
    return @"http://forums.somethingawful.com/showthread.php?threadid=3419934";
}

-(void)refresh
{
    AwfulTestPageRequest *req = [[AwfulTestPageRequest alloc] initWithAwfulTestPage:self];
    loadRequest(req);
    [req release];
}

-(void)setView:(UIView *)view
{
    [super setView:view];
    AwfulNavigator *nav = getNavigator();
    nav.view = view;
}

@end
