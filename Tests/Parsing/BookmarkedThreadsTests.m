//
//  BookmarkedThreadsTests.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app
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
    ThreadParsedInfo *second = threads[1];
    STAssertEqualObjects(second.title, @"Awful Android app", nil);
    STAssertTrue(second.seenPosts == 7955, nil);
    STAssertEqualObjects(second.lastPostAuthorName, @"spankmeister", nil);
    STAssertFalse(second.isClosed, nil);
    STAssertFalse(second.isSticky, nil);
    STAssertTrue(second.seen, nil);
    STAssertTrue(second.starCategory == AwfulStarCategoryRed, nil);
    STAssertEqualObjects([second.threadIconImageURL lastPathComponent], @"cps-android.gif", nil);
    
    ThreadParsedInfo *third = threads[2];
    STAssertTrue(third.starCategory == AwfulStarCategoryOrange, nil);
    
    ThreadParsedInfo *fifth = threads[4];
    STAssertTrue(fifth.starCategory == AwfulStarCategoryYellow, nil);
}

@end
