//
//  PrivateMessageTests.m
//  Awful
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app
//

#import "ParsingTests.h"

@interface PrivateMessageTests : ParsingTests @end
@implementation PrivateMessageTests

+ (NSString *)fixtureFilename { return @"private-one.html"; }

- (void)testPrivateMessageInfo
{
    PrivateMessageParsedInfo *info = [[PrivateMessageParsedInfo alloc]
                                      initWithHTMLData:self.fixture];
    STAssertEqualObjects(info.subject, @"Awful app", nil);
    STAssertEqualObjects(info.messageID, @"4601162", nil);
    STAssertEqualObjects(info.from.username, @"InFlames235", nil);
    STAssertEqualObjects(info.from.userID, @"47395", nil);
    STAssertNotNil(info.from.regdate, nil);
    STAssertStringContainsSubstringOnce(info.from.customTitle, @"as a cow", nil);
    STAssertFalse(info.replied, nil);
    STAssertTrue(info.seen, nil);
    STAssertNotNil(info.sentDate, nil);
    STAssertStringContainsSubstringOnce(info.innerHTML, @"an awesome app", nil);
}

@end


@interface PrivateMessageListTests : ParsingTests @end
@implementation PrivateMessageListTests

+ (NSString *)fixtureFilename { return @"private-list.html"; }

- (void)testPrivateMessageFolderInfo
{
    PrivateMessageFolderParsedInfo *info = [[PrivateMessageFolderParsedInfo alloc]
                                            initWithHTMLData:self.fixture];
    STAssertTrue([info.privateMessages count] == 3, nil);
    
    PrivateMessageParsedInfo *first = info.privateMessages[0];
    STAssertEqualObjects(first.subject, @"Re: Awful app", nil);
    STAssertEqualObjects(first.from.username, @"InFlames235", nil);
    STAssertFalse(first.replied, nil);
    STAssertTrue(first.seen, nil);
    
    PrivateMessageParsedInfo *second = info.privateMessages[1];
    STAssertEqualObjects(second.subject, @"Awful app", nil);
    STAssertEqualObjects(second.from.username, @"InFlames235", nil);
    STAssertTrue(second.replied, nil);
    STAssertTrue(second.seen, nil);
}

@end


@interface PrivateMessageComposeTests : ParsingTests @end
@implementation PrivateMessageComposeTests

+ (NSString *)fixtureFilename { return @"private-new.html"; }

- (void)testComposePrivateMessageInfo
{
    ComposePrivateMessageParsedInfo *info = [[ComposePrivateMessageParsedInfo alloc]
                                             initWithHTMLData:self.fixture];
    STAssertTrue([info.postIcons count] == 49, nil);
    NSURL *first = info.postIcons[@"692"];
    STAssertEqualObjects([first lastPathComponent], @"dd-9-11.gif", nil);
    STAssertEqualObjects(info.text, @"", nil);
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
    STAssertEqualObjects(prefix, @"\n\n[quote]\nInFlames235 wrote", nil);
}

@end
