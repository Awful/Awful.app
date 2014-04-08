//  UIBarButtonItem+AwfulConvenience.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIBarButtonItem+AwfulConvenience.h"

@implementation UIBarButtonItem (AwfulConvenience)

+ (instancetype)awful_flexibleSpace
{
    return [[self alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
}

+ (instancetype)awful_fixedSpace:(CGFloat)width
{
    UIBarButtonItem *item = [[self alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    item.width = width;
    return item;
}

+ (instancetype)awful_emptyBackBarButtonItem
{
    return [[self alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
}

@end
