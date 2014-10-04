//  WebArchiveTests.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

@import XCTest;
#import "SmilieWebArchive.h"

@interface WebArchiveTests : XCTestCase

@property (strong, nonatomic) SmilieWebArchive *archive;

@end

@implementation WebArchiveTests

- (SmilieWebArchive *)archive
{
    if (!_archive) {
        NSURL *archiveURL = [[NSBundle bundleForClass:[WebArchiveTests class]] URLForResource:@"showsmilies" withExtension:@"webarchive"];
        _archive = [[SmilieWebArchive alloc] initWithURL:archiveURL];
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
