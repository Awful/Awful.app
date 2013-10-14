//  UIBarButtonItem+AwfulConvenience.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIBarButtonItem+AwfulConvenience.h"

@implementation UIBarButtonItem (AwfulConvenience)

+ (instancetype)flexibleSpace
{
    return [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                         target:nil
                                                         action:nil];
}

@end
