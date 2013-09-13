//  AwfulToolbar.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulToolbar.h"

@implementation AwfulToolbar

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    self.barStyle = UIBarStyleBlackTranslucent;
    self.tintColor = [UIColor whiteColor];
    return self;
}

@end
