//  PrivateMessageTests.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "ParsingTests.h"

@interface PrivateMessageTests : ParsingTests @end
@implementation PrivateMessageTests

+ (NSString *)fixtureFilename { return @"private-one.html"; }

- (void)testPrivateMessageInfo
{
    PrivateMessageParsedInfo *info = [[PrivateMessageParsedInfo alloc]
                                      initWithHTMLData:self.fixture];
    XCTAssertEqualObjects(info.subject, @"Awful app");
    XCTAssertEqualObjects(info.messageID, @"4601162");
    XCTAssertEqualObjects(info.from.username, @"InFlames235");
    XCTAssertEqualObjects(info.from.userID, @"47395");
    XCTAssertNotNil(info.from.regdate);
    AwfulAssertStringContainsSubstringOnce(info.from.customTitleHTML, @"as a cow");
    XCTAssertFalse(info.replied);
    XCTAssertTrue(info.seen);
    XCTAssertNotNil(info.sentDate);
    AwfulAssertStringContainsSubstringOnce(info.innerHTML, @"an awesome app");
}

@end


@interface PrivateMessageListTests : ParsingTests @end
@implementation PrivateMessageListTests

+ (NSString *)fixtureFilename { return @"private-list.html"; }

- (void)testPrivateMessageFolderInfo
{
    PrivateMessageFolderParsedInfo *info = [[PrivateMessageFolderParsedInfo alloc]
                                            initWithHTMLData:self.fixture];
    XCTAssertTrue([info.privateMessages count] == 3);
    
    PrivateMessageParsedInfo *first = info.privateMessages[0];
    XCTAssertEqualObjects(first.subject, @"Re: Awful app");
    XCTAssertEqualObjects(first.from.username, @"InFlames235");
    XCTAssertFalse(first.replied);
    XCTAssertTrue(first.seen);
    
    PrivateMessageParsedInfo *second = info.privateMessages[1];
    XCTAssertEqualObjects(second.subject, @"Awful app");
    XCTAssertEqualObjects(second.from.username, @"InFlames235");
    XCTAssertTrue(second.replied);
    XCTAssertTrue(second.seen);
}

@end


@interface PrivateMessageComposeTests : ParsingTests @end
@implementation PrivateMessageComposeTests

+ (NSString *)fixtureFilename { return @"private-new.html"; }

- (void)testComposePrivateMessageInfo
{
    ComposePrivateMessageParsedInfo *info = [[ComposePrivateMessageParsedInfo alloc]
                                             initWithHTMLData:self.fixture];
    XCTAssertTrue([info.postIcons count] == 49);
    NSURL *first = info.postIcons[@"692"];
    XCTAssertEqualObjects([first lastPathComponent], @"dd-9-11.gif");
    XCTAssertEqualObjects(info.text, @"");
}

@end


@interface PrivateMessageReplyTests : ParsingTests @end
@implementation PrivateMessageReplyTests

+ (NSString *)fixtureFilename { return @"private-reply.html"; }

- (void)testReplyInfo
{
    ComposePrivateMessageParsedInfo *info = [[ComposePrivateMessageParsedInfo alloc]
                                             initWithHTMLData:self.fixture];
    NSString *prefix = [info.text substringToIndex:27];
    XCTAssertEqualObjects(prefix, @"\n\n[quote]\nInFlames235 wrote");
}

@end
