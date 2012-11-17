//
//  UINavigationItem+TwoLineTitle.m
//  Awful
//
//  Created by Nolan Waite on 2012-11-17.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import "UINavigationItem+TwoLineTitle.h"

@implementation UINavigationItem (TwoLineTitle)

- (UILabel *)titleLabel
{
    if (self.titleView) return (UILabel *)self.titleView;
    // UINavigationBar never seems to make our label taller, but it does position it nicely,
    // so we set an overly tall height to make sure we get two lines.
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 0, 100)];
    titleLabel.numberOfLines = 2;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        titleLabel.font = [UIFont boldSystemFontOfSize:17];
        titleLabel.minimumFontSize = 13;
    } else {
        titleLabel.font = [UIFont boldSystemFontOfSize:13];
        titleLabel.minimumFontSize = 9;
    }
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.backgroundColor = [UIColor clearColor];
    titleLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.5];
    titleLabel.textAlignment = UITextAlignmentLeft;
    titleLabel.adjustsFontSizeToFitWidth = YES;
    titleLabel.autoresizingMask = (UIViewAutoresizingFlexibleWidth |
                                   UIViewAutoresizingFlexibleHeight);
    self.titleView = titleLabel;
    return titleLabel;
}

- (void)setTitleLabel:(UILabel *)titleLabel
{
    self.titleView = titleLabel;
}

@end
