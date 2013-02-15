//
//  ThreadTests.m
//  Awful
//
//  Created by Nolan Waite on 2012-10-10.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "ParsingTests.h"

@interface ThreadTests : ParsingTests

@end


@implementation ThreadTests

+ (NSString *)fixtureFilename
{
    return @"showthread.html";
}

- (void)testPageInfo
{
    PageParsedInfo *info = [[PageParsedInfo alloc] initWithHTMLData:self.fixture];
    STAssertEquals(info.pageNumber, 5, nil);
    STAssertEquals(info.pagesInThread, 117, nil);
    STAssertEqualObjects(info.forumID, @"46", nil);
    STAssertEqualObjects(info.forumName, @"Debate & Discussion", nil);
    STAssertEqualObjects(info.threadID, @"3507451", nil);
    STAssertEqualObjects(info.threadTitle,
                         @"Canadian Politics Thread: Revenge of Trudeaumania: Brawl Me, Maybe",
                         nil);
    STAssertFalse(info.threadClosed, nil);
    STAssertTrue(info.threadBookmarked, nil);
    STAssertEquals([info.posts count], 40U, nil);
}

- (void)testPostInfo
{
    PageParsedInfo *info = [[PageParsedInfo alloc] initWithHTMLData:self.fixture];
    NSDateFormatter *formatter = [NSDateFormatter new];
    
    PostParsedInfo *first = info.posts[0];
    STAssertEqualObjects(first.postID, @"407741839", nil);
    STAssertEqualObjects(first.threadIndex, @"161", nil);
    [formatter setDateFormat:@"MMM dd, yyyy  h:mm a"];
    STAssertEqualObjects([formatter stringFromDate:first.postDate], @"Sep 20, 2012  8:16 AM", nil);
    STAssertTrue(first.beenSeen, nil);
    STAssertFalse(first.editable, nil);
    
    PostParsedInfo *tenth = info.posts[10];
    STAssertEqualObjects(tenth.postID, @"407751664", nil);
    STAssertEqualObjects(tenth.threadIndex, @"171", nil);
    STAssertEqualObjects(tenth.author.username, @"JayMax", nil);
    STAssertTrue([tenth.innerHTML rangeOfString:@"Québec"].location != NSNotFound, nil);
    STAssertTrue([tenth.author.customTitle rangeOfString:@"gentleman"].location != NSNotFound, nil);
    STAssertTrue(tenth.beenSeen, nil);
    STAssertFalse(tenth.editable, nil);
    
    PostParsedInfo *twelfth = info.posts[12];
    STAssertEqualObjects(twelfth.postID, @"407751956", nil);
    STAssertEqualObjects(twelfth.threadIndex, @"173", nil);
    STAssertEqualObjects(twelfth.author.username, @"Dreylad", nil);
    STAssertTrue(twelfth.author.originalPoster, nil);
    STAssertFalse(twelfth.author.moderator, nil);
    STAssertFalse(twelfth.beenSeen, nil);
    STAssertFalse(twelfth.editable, nil);
    
    PostParsedInfo *fourteenth = info.posts[14];
    STAssertEqualObjects(fourteenth.postID, @"407753032", nil);
    STAssertEqualObjects(fourteenth.threadIndex, @"175", nil);
    STAssertEqualObjects(fourteenth.author.username, @"angerbot", nil);
    STAssertTrue(fourteenth.author.administrator, nil);
    STAssertFalse(fourteenth.author.moderator, nil);
    STAssertTrue([fourteenth.author.customTitle rangeOfString:@"/images/angerbrat.jpg"].length != 0, nil);
    STAssertFalse(fourteenth.beenSeen, nil);
    STAssertFalse(fourteenth.editable, nil);
    
    PostParsedInfo *twentyFirst = info.posts[21];
    STAssertFalse(twentyFirst.beenSeen, nil);
    STAssertFalse(twentyFirst.editable, nil);
    
    PostParsedInfo *last = [info.posts lastObject];
    STAssertEqualObjects(last.postID, @"407769816", nil);
    STAssertEqualObjects(last.threadIndex, @"200", nil);
    [formatter setDateFormat:@"MMM dd, yyyy"];
    STAssertEqualObjects([formatter stringFromDate:last.author.regdate], @"Aug 25, 2009", nil);
    STAssertFalse(last.beenSeen, nil);
    STAssertFalse(last.editable, nil);
}

@end


@interface WeirdSizeTagTests : ParsingTests @end

@implementation WeirdSizeTagTests

+ (NSString *)fixtureFilename { return @"showthread2.html"; }

- (void)testPageInfo
{
    PageParsedInfo *info = [[PageParsedInfo alloc] initWithHTMLData:self.fixture];
    PostParsedInfo *ganker = info.posts[24];
    STAssertEqualObjects(ganker.author.username, @"Ganker", nil);
    PostParsedInfo *afterGanker = info.posts[25];
    STAssertEqualObjects(afterGanker.author.username, @"brylcreem", nil);
}

@end
