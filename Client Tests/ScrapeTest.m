//
//  ScrapeTest.m
//  Awful
//
//  Created by Nolan Waite on 12-05-05.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <GHUnitIOS/GHUnit.h>
#import "AwfulScrapeOperation.h"

@interface ScrapeTest : GHTestCase @end

@implementation ScrapeTest

- (void)testForumList
{
    AwfulForumListScrapeOperation *op = [[AwfulForumListScrapeOperation alloc] initWithResponseData:
                                         BundleData(@"gbs.html")];
    [op start];
    
    NSArray *forums = [op.scrapings objectForKey:AwfulScrapingsKeys.Forums];
    GHAssertEquals(forums.count, 76U, nil);
    
    NSDictionary *gbs = [forums objectAtIndex:1];
    GHAssertEqualStrings([gbs objectForKey:@"name"], @"General Bullshit", nil);
    GHAssertEqualStrings([[gbs objectForKey:@"parent"] objectForKey:@"name"], @"Main", nil);
    
    NSDictionary *sc2 = [forums objectAtIndex:10];
    GHAssertEqualStrings([sc2 objectForKey:@"name"], @"The StarCraft II Zealot Zone", nil);
    NSDictionary *games = [[sc2 objectForKey:@"parent"] objectForKey:@"parent"];
    GHAssertEqualStrings([games objectForKey:@"name"], @"Games", nil);
}

@end
