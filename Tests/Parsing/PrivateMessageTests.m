//
//  PrivateMessageTests.m
//  Awful
//
//  Created by Nolan Waite on 2013-02-25.
//  Copyright (c) 2013 Regular Berry Software LLC. All rights reserved.
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
