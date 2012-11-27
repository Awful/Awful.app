//
//  UINavigationItem+TwoLineTitle.m
//  Awful
//
//  Created by Nolan Waite on 2012-11-17.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "UINavigationItem+TwoLineTitle.h"

@interface CenteringThreadTitleLabelHolder : UIView

@property (weak, nonatomic) UILabel *label;

@end


@implementation UINavigationItem (TwoLineTitle)

- (UILabel *)titleLabel
{
    if (self.titleView) return [(CenteringThreadTitleLabelHolder *)self.titleView label];
    CenteringThreadTitleLabelHolder *holder = [CenteringThreadTitleLabelHolder new];
    holder.frame = CGRectMake(0, 0, 1024, 32);
    holder.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    self.titleView = holder;
    return holder.label;
}

- (void)setTitleLabel:(UILabel *)titleLabel
{
    self.titleView = titleLabel;
}

@end


@implementation CenteringThreadTitleLabelHolder

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    UILabel *label = [UILabel new];
    label.textAlignment = UITextAlignmentCenter;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        label.font = [UIFont boldSystemFontOfSize:17];
    } else {
        label.font = [UIFont boldSystemFontOfSize:13];
        label.numberOfLines = 2;
    }
    label.textColor = [UIColor whiteColor];
    label.backgroundColor = [UIColor clearColor];
    label.shadowColor = [UIColor colorWithWhite:0 alpha:0.5];
    NSComparisonResult atLeastSix = [[UIDevice currentDevice].systemVersion
                                     compare:@"6.0" options:NSNumericSearch];
    if (atLeastSix != NSOrderedAscending) {
        label.accessibilityTraits |= UIAccessibilityTraitHeader;
    }
    [self addSubview:label];
    self.label = label;
    return self;
}

- (void)layoutSubviews
{
    CGFloat leftOffset = CGRectGetMinX(self.frame);
    CGFloat rightOffset = self.superview.bounds.size.width - CGRectGetMaxX(self.frame);
    CGRect absolutelyCenteredFrame = self.bounds;
    absolutelyCenteredFrame.size.width -= fabs(leftOffset - rightOffset);
    if (rightOffset > leftOffset) absolutelyCenteredFrame.origin.x += (rightOffset - leftOffset);
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        self.label.frame = absolutelyCenteredFrame;
        return;
    }
    CGSize fits = [self.label.text sizeWithFont:self.label.font
                              constrainedToSize:absolutelyCenteredFrame.size];
    if (fits.height / self.label.font.leading > 1.5) {
        self.label.textAlignment = UITextAlignmentLeft;
        self.label.frame = self.bounds;
    } else {
        self.label.textAlignment = UITextAlignmentCenter;
        self.label.frame = absolutelyCenteredFrame;
    }
}

@end
