//  AwfulScanner.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScanner.h"

NS_ASSUME_NONNULL_BEGIN

@implementation NSScanner (AwfulScanner)

/// A scanner created with this method ignores no characters and is case sensitive.
+ (instancetype)awful_scannerWithString:(NSString *)string
{
    NSScanner *scanner = [self scannerWithString:string];
    scanner.charactersToBeSkipped = nil;
    scanner.caseSensitive = YES;
    return scanner;
}

@end

NS_ASSUME_NONNULL_END
