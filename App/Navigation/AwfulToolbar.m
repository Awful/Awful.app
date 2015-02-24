//  AwfulToolbar.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulToolbar.h"

@implementation AwfulToolbar

- (instancetype)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
        self.tintColor = [UIColor colorWithRed:0.078 green:0.514 blue:0.694 alpha:1];
    }
    return self;
}

@end
