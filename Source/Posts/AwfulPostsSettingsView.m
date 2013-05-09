//
//  AwfulPostsSettingsView.m
//  Awful
//
//  Created by Nolan Waite on 2013-04-11.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulPostsSettingsView.h"

@interface AwfulPostsSettingsView ()

@property (weak, nonatomic) UILabel *showAvatarsLabel;
@property (weak, nonatomic) UISwitch *showAvatarsSwitch;
@property (weak, nonatomic) UILabel *showImagesLabel;
@property (weak, nonatomic) UISwitch *showImagesSwitch;
@property (weak, nonatomic) UIView *upperSeparator;
@property (weak, nonatomic) UILabel *fontSizeLabel;
@property (weak, nonatomic) UIStepper *fontSizeStepper;
@property (weak, nonatomic) UIView *lowerSeparator;
@property (weak, nonatomic) UILabel *themeLabel;
@property (weak, nonatomic) AwfulThemePicker *themePicker;

@end


@implementation AwfulPostsSettingsView

#pragma mark - UIView

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
    self.clipsToBounds = NO;
    
    #define AddAndSetSubview(viewClass, ivar) do { \
        viewClass *ivar = [viewClass new]; \
        [self addSubview:ivar]; \
        _##ivar = ivar; \
    } while (0)
    AddAndSetSubview(UILabel, showAvatarsLabel);
    self.showAvatarsLabel.text = @"Avatars";
    ConfigureLabel(self.showAvatarsLabel);
    AddAndSetSubview(UISwitch, showAvatarsSwitch);
    AddAndSetSubview(UILabel, showImagesLabel);
    self.showImagesLabel.text = @"Images";
    ConfigureLabel(self.showImagesLabel);
    AddAndSetSubview(UISwitch, showImagesSwitch);
    AddAndSetSubview(UIView, upperSeparator);
    ConfigureSeparator(self.upperSeparator);
    AddAndSetSubview(UILabel, fontSizeLabel);
    self.fontSizeLabel.text = @"Font Size";
    ConfigureLabel(self.fontSizeLabel);
    self.fontSizeLabel.textAlignment = NSTextAlignmentRight;
    AddAndSetSubview(UIStepper, fontSizeStepper);
    AddAndSetSubview(UIView, lowerSeparator);
    ConfigureSeparator(self.lowerSeparator);
    AddAndSetSubview(UILabel, themeLabel);
    self.themeLabel.text = @"Theme";
    ConfigureLabel(self.themeLabel);
    AddAndSetSubview(AwfulThemePicker, themePicker);
    return self;
}

static void ConfigureLabel(UILabel *label)
{
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [UIColor whiteColor];
    label.font = [UIFont boldSystemFontOfSize:16];
}

static void ConfigureSeparator(UIView *separator)
{
    separator.backgroundColor = [UIColor darkGrayColor];
}

- (void)layoutSubviews
{
    CGRect bounds = CGRectInset(self.bounds, 8, 0);
    CGRect topThird, middleThird, bottomThird;
    CGRectDivide(bounds, &topThird, &middleThird, floorf(CGRectGetHeight(bounds) / 3), CGRectMinYEdge);
    middleThird.origin.y += 1;
    middleThird.size.height -= 1;
    CGRectDivide(middleThird, &middleThird, &bottomThird, CGRectGetHeight(topThird), CGRectMinYEdge);
    bottomThird.origin.y += 1;
    bottomThird.size.height -= 1;
    
    CGRect avatarsSixth, imagesSixth;
    CGRectDivide(topThird, &avatarsSixth, &imagesSixth, floorf(CGRectGetWidth(topThird) / 2), CGRectMinXEdge);
    avatarsSixth.size.width -= 8;
    imagesSixth.origin.x += 8;
    imagesSixth.size.width -= 8;
    CGRect avatarsLabelFrame, avatarsSwitchFrame;
    CGSize switchSize = self.showAvatarsSwitch.bounds.size;
    CGRectDivide(avatarsSixth, &avatarsSwitchFrame, &avatarsLabelFrame, switchSize.width, CGRectMaxXEdge);
    self.showAvatarsSwitch.center = CGPointMake(CGRectGetMidX(avatarsSwitchFrame), CGRectGetMidY(avatarsSwitchFrame));
    self.showAvatarsLabel.frame = avatarsLabelFrame;
    CGRect imagesLabelFrame, imagesSwitchFrame;
    CGRectDivide(imagesSixth, &imagesSwitchFrame, &imagesLabelFrame, switchSize.width, CGRectMaxXEdge);
    self.showImagesSwitch.center = CGPointMake(CGRectGetMidX(imagesSwitchFrame), CGRectGetMidY(imagesSwitchFrame));
    self.showImagesLabel.frame = imagesLabelFrame;
    
    self.upperSeparator.frame = CGRectMake(0, CGRectGetMaxY(topThird) + 1, CGRectGetWidth(self.bounds), 1);
    
    [self.fontSizeLabel sizeToFit];
    self.fontSizeLabel.center = CGPointMake(CGRectGetMinX(middleThird) + CGRectGetWidth(self.fontSizeLabel.bounds) / 2, CGRectGetMidY(middleThird));
    self.fontSizeStepper.center = CGPointMake(CGRectGetMaxX(self.fontSizeLabel.frame) + CGRectGetWidth(self.fontSizeStepper.bounds) / 2 + 8, self.fontSizeLabel.center.y);
    
    self.lowerSeparator.frame = CGRectMake(0, CGRectGetMaxY(middleThird) + 1, CGRectGetWidth(self.bounds), 1);
    
    [self.themeLabel sizeToFit];
    CGRect themeLabelFrame, themePickerFrame;
    CGRectDivide(bottomThird, &themeLabelFrame, &themePickerFrame, CGRectGetWidth(self.themeLabel.bounds), CGRectMinXEdge);
    self.themeLabel.frame = themeLabelFrame;
    themePickerFrame.origin.x += 16;
    themePickerFrame.size.width -= 16;
    self.themePicker.frame = themePickerFrame;
}

@end
