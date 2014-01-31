//  UINavigationItem+TwoLineTitle.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>

@interface UINavigationItem (TwoLineTitle)

/**
 * A replacement label for the title that shows two lines.
 */
@property (readonly, strong, nonatomic) UILabel *titleLabel;

@end
