//  ParsingTests.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "ParsingTests.h"

@implementation ParsingTests
{
    NSData *_fixture;
}

+ (NSString *)fixtureFilename
{
    [NSException raise:NSInternalInconsistencyException
                format:@"subclasses must override %@", NSStringFromSelector(_cmd)];
    return nil;
}

- (NSData *)fixture
{
    if (_fixture) return _fixture;
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    NSString *fixturePath = [@"Fixtures" stringByAppendingPathComponent:[[self class] fixtureFilename]];
    NSURL *fixtureURL = [bundle URLForResource:fixturePath withExtension:nil];
    NSString *dumbCharset = [NSString stringWithContentsOfURL:fixtureURL
                                                     encoding:NSWindowsCP1252StringEncoding
                                                        error:NULL];
    _fixture = [dumbCharset dataUsingEncoding:NSUTF8StringEncoding];
    return _fixture;
}

@end
