//
//  ParsingTests.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

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

- (void)setUp
{
    if (!_fixture) {
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSURL *fixtureURL = [bundle URLForResource:[[self class] fixtureFilename]
                                     withExtension:nil];
        NSString *dumbCharset = [NSString stringWithContentsOfURL:fixtureURL
                                                         encoding:NSWindowsCP1252StringEncoding
                                                            error:NULL];
        _fixture = [dumbCharset dataUsingEncoding:NSUTF8StringEncoding];
    }
}

@end
