//
//  BookmarkedThreadsTests.m
//  Awful
//
//  Created by Nolan Waite on 2012-10-10.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "ParsingTests.h"
#import "AwfulThread.h"

@interface BookmarkedThreadsTests : ParsingTests @end
@implementation BookmarkedThreadsTests

+ (NSString *)fixtureFilename { return @"bookmarkthreads.html"; }

- (void)testBookmarkedThreads
{
    NSArray *threads = [ThreadParsedInfo threadsWithHTMLData:self.fixture];
    STAssertTrue([threads count] == 11, nil);
    ThreadParsedInfo *third = threads[2];
    STAssertEqualObjects(third.title, @"Awful Android app", nil);
    STAssertTrue(third.totalUnreadPosts == 0, nil);
    STAssertEqualObjects(third.lastPostAuthorName, @"AlexMoron", nil);
    STAssertFalse(third.isClosed, nil);
    STAssertFalse(third.isSticky, nil);
    STAssertTrue(third.seen, nil);
    STAssertTrue(third.starCategory == AwfulStarCategoryNone, nil);
    STAssertEqualObjects([third.threadIconImageURL lastPathComponent], @"cps-android.gif", nil);
}

@end
