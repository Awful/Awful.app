//  ThreadTests.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

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
    XCTAssertEqual(info.pageNumber, 5);
    XCTAssertEqual(info.pagesInThread, 151);
    XCTAssertEqualObjects(info.forumID, @"46");
    XCTAssertEqualObjects(info.forumName, @"Debate & Discussion");
    XCTAssertEqualObjects(info.threadID, @"3507451");
    XCTAssertEqualObjects(info.threadTitle,
                         @"Canadian Politics Thread: Revenge of Trudeaumania: Brawl Me, Maybe");
    XCTAssertFalse(info.threadClosed);
    XCTAssertTrue(info.threadBookmarked);
    XCTAssertEqual([info.posts count], 40U);
}

- (void)testPostInfo
{
    PageParsedInfo *info = [[PageParsedInfo alloc] initWithHTMLData:self.fixture];
    NSDateFormatter *formatter = [NSDateFormatter new];
    
    PostParsedInfo *first = info.posts[0];
    XCTAssertEqualObjects(first.postID, @"407741839");
    XCTAssertEqualObjects(first.threadIndex, @"161");
    [formatter setDateFormat:@"MMM dd, yyyy  h:mm a"];
    XCTAssertEqualObjects([formatter stringFromDate:first.postDate], @"Sep 20, 2012  11:16 AM");
    XCTAssertTrue(first.beenSeen);
    XCTAssertFalse(first.editable);
    
    PostParsedInfo *tenth = info.posts[10];
    XCTAssertEqualObjects(tenth.postID, @"407751664");
    XCTAssertEqualObjects(tenth.threadIndex, @"171");
    XCTAssertEqualObjects(tenth.author.username, @"JayMax");
    XCTAssertTrue([tenth.innerHTML rangeOfString:@"Québec"].location != NSNotFound);
    XCTAssertTrue([tenth.author.customTitleHTML rangeOfString:@"gentleman"].location != NSNotFound);
    XCTAssertTrue(tenth.beenSeen);
    XCTAssertFalse(tenth.editable);
    XCTAssertTrue(tenth.author.canReceivePrivateMessages);
    
    PostParsedInfo *eleventh = info.posts[11];
    XCTAssertFalse(eleventh.author.canReceivePrivateMessages);
    
    PostParsedInfo *twelfth = info.posts[12];
    XCTAssertEqualObjects(twelfth.postID, @"407751956");
    XCTAssertEqualObjects(twelfth.threadIndex, @"173");
    XCTAssertEqualObjects(twelfth.author.username, @"Dreylad");
    XCTAssertTrue(twelfth.author.originalPoster);
    XCTAssertFalse(twelfth.author.moderator);
    XCTAssertFalse(twelfth.beenSeen);
    XCTAssertFalse(twelfth.editable);
    
    PostParsedInfo *fourteenth = info.posts[14];
    XCTAssertEqualObjects(fourteenth.postID, @"407753032");
    XCTAssertEqualObjects(fourteenth.threadIndex, @"175");
    XCTAssertEqualObjects(fourteenth.author.username, @"angerbot");
    XCTAssertTrue(fourteenth.author.administrator);
    XCTAssertFalse(fourteenth.author.moderator);
    XCTAssertTrue([fourteenth.author.customTitleHTML rangeOfString:@"/images/angerbrat.jpg"].length != 0);
    XCTAssertFalse(fourteenth.beenSeen);
    XCTAssertFalse(fourteenth.editable);
    
    PostParsedInfo *twentyFirst = info.posts[21];
    XCTAssertFalse(twentyFirst.beenSeen);
    XCTAssertFalse(twentyFirst.editable);
    
    PostParsedInfo *last = [info.posts lastObject];
    XCTAssertEqualObjects(last.postID, @"407769816");
    XCTAssertEqualObjects(last.threadIndex, @"200");
    formatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
    [formatter setDateFormat:@"MMM dd, yyyy"];
    XCTAssertEqualObjects([formatter stringFromDate:last.author.regdate], @"Aug 25, 2009");
    XCTAssertFalse(last.beenSeen);
    XCTAssertFalse(last.editable);
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
    XCTAssertEqualObjects(ganker.author.username, @"Ganker");
    PostParsedInfo *afterGanker = info.posts[25];
    XCTAssertEqualObjects(afterGanker.author.username, @"brylcreem");
}

@end


@interface NewThreadTests : ParsingTests @end

@implementation NewThreadTests

+ (NSString *)fixtureFilename { return @"newthread.html"; }

- (void)testNewThreadID
{
    SuccessfulNewThreadParsedInfo *info = [[SuccessfulNewThreadParsedInfo alloc]
                                           initWithHTMLData:self.fixture];
    XCTAssertEqualObjects(info.threadID, @"3550424");
}

@end


@interface NewAskTellThreadTests : ParsingTests @end

@implementation NewAskTellThreadTests

+ (NSString *)fixtureFilename { return @"newthread-at.html"; }

- (void)testNewThreadForm
{
    NewThreadFormParsedInfo *info = [[NewThreadFormParsedInfo alloc] initWithHTMLData:self.fixture];
    XCTAssertEqualObjects(info.formkey, @"abc123");
    XCTAssertEqualObjects(info.formCookie, @"heyhey");
    XCTAssertEqualObjects(info.automaticallyParseURLs, @"yes");
    XCTAssertNil(info.bookmarkThread);
}

- (void)testIconIDs
{
    ComposePrivateMessageParsedInfo *info = [[ComposePrivateMessageParsedInfo alloc]
                                             initWithHTMLData:self.fixture];
    XCTAssertEqualObjects([[info.postIcons[@"526"] lastPathComponent] stringByDeletingPathExtension],
                         @"lf-9287");
    XCTAssertTrue([info.postIconIDs containsObject:@"322"]);
    
    XCTAssertEqualObjects([info.secondaryIcons[@"0"] lastPathComponent], @"tma.gif");
    XCTAssertTrue([info.secondaryIconIDs containsObject:@"1"]);
    XCTAssertEqualObjects(info.secondaryIconKey, @"tma_ama");
    XCTAssertEqualObjects(info.selectedSecondaryIconID, @"0");
}

@end

@interface NewSAMartThreadTests : ParsingTests @end

@implementation NewSAMartThreadTests

+ (NSString *)fixtureFilename { return @"newthread-samart.html"; }

- (void)testIconIDs
{
    ComposePrivateMessageParsedInfo *info = [[ComposePrivateMessageParsedInfo alloc]
                                             initWithHTMLData:self.fixture];
    XCTAssertEqualObjects(info.secondaryIconKey, @"samart_tag");
    XCTAssertTrue([info.secondaryIconIDs containsObject:@"4"]);
    XCTAssertEqualObjects([info.secondaryIcons[@"1"] lastPathComponent], @"icon-37-selling.gif");
    XCTAssertEqualObjects(info.selectedSecondaryIconID, @"1");
}

@end
