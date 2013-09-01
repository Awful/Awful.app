//  UINavigationItem+TwoLineTitle.m
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UINavigationItem+TwoLineTitle.h"
#import "UIDevice+OperatingSystemVersion.h"

@interface UINavigationItem ()

@property (readonly, nonatomic) UILabel *titleLabel;

@end


@implementation UINavigationItem (TwoLineTitle)

- (UILabel *)titleLabel
{
    if (self.titleView) return (id)self.titleView;
    UILabel *label = [UILabel new];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    label.textAlignment = NSTextAlignmentCenter;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        label.font = [UIFont boldSystemFontOfSize:17];
    } else {
        label.font = [UIFont boldSystemFontOfSize:13];
        label.numberOfLines = 2;
    }
    label.frame = CGRectMake(0, 0, 320, label.font.lineHeight * label.numberOfLines);
    label.textColor = [UIColor whiteColor];
    label.backgroundColor = [UIColor clearColor];
    label.shadowColor = [UIColor colorWithWhite:0 alpha:0.5];
    if ([[UIDevice currentDevice] awful_iOS6OrLater]) {
        label.accessibilityTraits |= UIAccessibilityTraitHeader;
    }
    self.titleView = label;
    return label;
}

@end
