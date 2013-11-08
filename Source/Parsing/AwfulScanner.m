//  AwfulScanner.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScanner.h"

@implementation AwfulScanner

static inline id CommonInit(NSScanner *self)
{
    self.charactersToBeSkipped = nil;
    self.caseSensitive = YES;
    return self;
}

// NSScanner has no designated initializer :-(

+ (instancetype)scannerWithString:(NSString *)string
{
    return CommonInit([super scannerWithString:string]);
}

+ (instancetype)localizedScannerWithString:(NSString *)string
{
    return CommonInit([super localizedScannerWithString:string]);
}

- (id)initWithString:(NSString *)string
{
    return CommonInit([super initWithString:string]);
}

@end
