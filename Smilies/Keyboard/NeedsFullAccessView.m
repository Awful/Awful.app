//  NeedsFullAccessView.m
//
//  Copyright 2014 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "NeedsFullAccessView.h"

@implementation NeedsFullAccessView

+ (instancetype)newFromNib
{
    return [[NSBundle bundleForClass:[NeedsFullAccessView class]] loadNibNamed:@"NeedsFullAccessView" owner:self options:nil][0];
}

@end
