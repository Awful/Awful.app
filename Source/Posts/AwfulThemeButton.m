//
//  AwfulThemeButton.m
//  Awful
//
//  Created by Nolan Waite on 2013-04-12.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulThemeButton.h"

@implementation AwfulThemeButton

#pragma mark - UIControl

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    if (selected) {
        self.layer.borderColor = SelectedColor().CGColor;
        self.layer.borderWidth = 2;
        self.layer.shadowOpacity = 1;
    } else {
        self.layer.borderColor = NormalColor().CGColor;
        self.layer.borderWidth = 1;
        self.layer.shadowOpacity = 0;
    }
}

static UIColor * NormalColor()
{
    return [UIColor darkGrayColor];
}

static UIColor * SelectedColor()
{
    return [UIColor colorWithHue:0.576 saturation:0.537 brightness:0.941 alpha:1];
}

#pragma mark - UIView

- (id)initWithFrame:(CGRect)frame
{
    if (CGRectEqualToRect(frame, CGRectZero)) {
        frame = CGRectMake(0, 0, 0, 32);
    }
    if (!(self = [super initWithFrame:frame])) return nil;
    self.layer.cornerRadius = 10;
    self.layer.borderColor = NormalColor().CGColor;
    self.layer.borderWidth = 1;
    self.layer.shadowColor = SelectedColor().CGColor;
    self.layer.shadowOffset = CGSizeZero;
    [self setTitle:@"✓" forState:UIControlStateSelected];
    [self setTitleColor:SelectedColor() forState:UIControlStateSelected];
    [self setTitleShadowColor:[UIColor whiteColor] forState:UIControlStateSelected];
    return self;
}

@end
