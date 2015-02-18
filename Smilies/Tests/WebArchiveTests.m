//  WebArchiveTests.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "Helpers.h"

@interface WebArchiveTests : XCTestCase

@property (strong, nonatomic) SmilieWebArchive *archive;

@end

@implementation WebArchiveTests

- (SmilieWebArchive *)archive
{
    if (!_archive) {
        _archive = FixtureWebArchive();
    }
    return _archive;
}

- (void)testMainFrameHTML
{
    NSRange range = [self.archive.mainFrameHTML rangeOfString:@":backtowork:"];
    XCTAssert(range.location != NSNotFound);
}

- (void)testSubresourceData
{
    NSURL *URL = [NSURL URLWithString:@"http://i.somethingawful.com/forumsystem/emoticons/emot-backtowork.gif"];
    NSData *scallopData = [self.archive dataForSubresourceWithURL:URL];
    char header[4] = {0};
    [scallopData getBytes:header length:3];
    XCTAssert(strncmp(header, "GIF", 3) == 0);
}

@end
