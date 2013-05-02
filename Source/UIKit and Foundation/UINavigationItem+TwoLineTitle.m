//
//  UINavigationItem+TwoLineTitle.m
//  Awful
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import "UINavigationItem+TwoLineTitle.h"

@interface UINavigationItem ()

@property (readonly, nonatomic) UILabel *titleLabel;

@end


@implementation UINavigationItem (TwoLineTitle)

- (UILabel *)titleLabel
{
    if (self.titleView) return (id)self.titleView;
    UILabel *label = [UILabel new];
    label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    label.textAlignment = UITextAlignmentCenter;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        label.font = [UIFont boldSystemFontOfSize:17];
    } else {
        label.font = [UIFont boldSystemFontOfSize:13];
        label.numberOfLines = 2;
    }
    label.frame = CGRectMake(0, 0, 0, label.font.lineHeight * label.numberOfLines);
    label.textColor = [UIColor whiteColor];
    label.backgroundColor = [UIColor clearColor];
    label.shadowColor = [UIColor colorWithWhite:0 alpha:0.5];
    label.accessibilityTraits |= UIAccessibilityTraitHeader;
    self.titleView = label;
    return label;
}

@end
