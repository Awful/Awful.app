//  Smilie.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "Smilie.h"
#import <HTMLReader/HTMLReader.h>

@implementation Smilie

- (instancetype)init
{
    if ((self = [super init])) {
        NSLog(@"check out my doc: %@", [HTMLDocument new]);
    }
    return self;
}

@end
