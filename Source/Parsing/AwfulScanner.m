//  AwfulScanner.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulScanner.h"

@implementation AwfulScanner

- (id)initWithString:(NSString *)string
{
    self = [super initWithString:string];
    if (!self) return nil;
    self.charactersToBeSkipped = nil;
    self.caseSensitive = YES;
    return self;
}

@end
