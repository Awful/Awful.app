//
//  ThreadTests.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app
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
    STAssertEquals(info.pagesInThread, 151, nil);
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
    STAssertEqualObjects([formatter stringFromDate:first.postDate], @"Sep 20, 2012  11:16 AM", nil);
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
    STAssertTrue(tenth.author.canReceivePrivateMessages, nil);
    
    PostParsedInfo *eleventh = info.posts[11];
    STAssertFalse(eleventh.author.canReceivePrivateMessages, nil);
    
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
    formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
    [formatter setDateFormat:@"MMM dd, yyyy"];
    STAssertEqualObjects([formatter stringFromDate:last.author.regdate], @"Aug 25, 2009", nil);
    STAssertFalse(last.beenSeen, nil);
    STAssertFalse(last.editable, nil);
}

@end


// Some posts end up with a pseudo-HTML tag that looks something like <size:2></size:2>. libxml
// gagged on this, so now we clean it out. The error was spotted when all posts after one with a
// <size> tag weren't parsed at all.
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


@interface NewThreadTests : ParsingTests @end

@implementation NewThreadTests

+ (NSString *)fixtureFilename { return @"newthread.html"; }

- (void)testNewThreadID
{
    SuccessfulNewThreadParsedInfo *info = [[SuccessfulNewThreadParsedInfo alloc]
                                           initWithHTMLData:self.fixture];
    STAssertEqualObjects(info.threadID, @"3550424", nil);
}

@end


@interface NewAskTellThreadTests : ParsingTests @end

@implementation NewAskTellThreadTests

+ (NSString *)fixtureFilename { return @"newthread-at.html"; }

- (void)testNewThreadForm
{
    NewThreadFormParsedInfo *info = [[NewThreadFormParsedInfo alloc] initWithHTMLData:self.fixture];
    STAssertEqualObjects(info.formkey, @"abc123", nil);
    STAssertEqualObjects(info.formCookie, @"heyhey", nil);
    STAssertEqualObjects(info.automaticallyParseURLs, @"yes", nil);
    STAssertNil(info.bookmarkThread, nil);
}

- (void)testIconIDs
{
    ComposePrivateMessageParsedInfo *info = [[ComposePrivateMessageParsedInfo alloc]
                                             initWithHTMLData:self.fixture];
    STAssertEqualObjects([[info.postIcons[@"526"] lastPathComponent] stringByDeletingPathExtension],
                         @"lf-9287", nil);
    STAssertTrue([info.postIconIDs containsObject:@"322"], nil);
    
    STAssertEqualObjects([info.secondaryIcons[@"0"] lastPathComponent], @"tma.gif", nil);
    STAssertTrue([info.secondaryIconIDs containsObject:@"1"], nil);
    STAssertEqualObjects(info.secondaryIconKey, @"tma_ama", nil);
    STAssertEqualObjects(info.selectedSecondaryIconID, @"0", nil);
}

@end

@interface NewSAMartThreadTests : ParsingTests @end

@implementation NewSAMartThreadTests

+ (NSString *)fixtureFilename { return @"newthread-samart.html"; }

- (void)testIconIDs
{
    ComposePrivateMessageParsedInfo *info = [[ComposePrivateMessageParsedInfo alloc]
                                             initWithHTMLData:self.fixture];
    STAssertEqualObjects(info.secondaryIconKey, @"samart_tag", nil);
    STAssertTrue([info.secondaryIconIDs containsObject:@"4"], nil);
    STAssertEqualObjects([info.secondaryIcons[@"1"] lastPathComponent], @"icon-37-selling.gif",
                         nil);
    STAssertEqualObjects(info.selectedSecondaryIconID, @"1", nil);
}

@end
