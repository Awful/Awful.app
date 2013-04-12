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
@property (weak, nonatomic) UILabel *fontSizeLabel;
@property (weak, nonatomic) UIStepper *fontSizeStepper;
@property (weak, nonatomic) UILabel *themeLabel;
@property (weak, nonatomic) AwfulThemePicker *themePicker;

@end


@implementation AwfulPostsSettingsView

#pragma mark - UIView

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.6];
    self.layer.shadowOffset = CGSizeMake(0, -3);
    self.layer.shadowOpacity = 1;
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
    AddAndSetSubview(UILabel, fontSizeLabel);
    self.fontSizeLabel.text = @"Font Size";
    ConfigureLabel(self.fontSizeLabel);
    self.fontSizeLabel.textAlignment = NSTextAlignmentRight;
    AddAndSetSubview(UIStepper, fontSizeStepper);
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

- (void)layoutSubviews
{
    CGRect bounds = CGRectInset(self.bounds, 8, 0);
    CGRect topThird, middleThird, bottomThird;
    CGRectDivide(bounds, &topThird, &middleThird, floorf(CGRectGetHeight(bounds) / 3), CGRectMinYEdge);
    CGRectDivide(middleThird, &middleThird, &bottomThird, CGRectGetHeight(topThird), CGRectMinYEdge);
    
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
    
    CGRect fontSizeLabelFrame, fontSizeStepperFrame;
    CGRectDivide(middleThird, &fontSizeLabelFrame, &fontSizeStepperFrame, floorf(CGRectGetWidth(middleThird) / 2), CGRectMinXEdge);
    fontSizeLabelFrame.size.width -= 4;
    fontSizeStepperFrame.origin.x += 4;
    fontSizeStepperFrame.size.width -= 4;
    self.fontSizeLabel.frame = fontSizeLabelFrame;
    self.fontSizeStepper.center = CGPointMake(CGRectGetMinX(fontSizeStepperFrame) + CGRectGetWidth(self.fontSizeStepper.bounds) / 2, CGRectGetMidY(fontSizeStepperFrame));
    
    [self.themeLabel sizeToFit];
    CGRect themeLabelFrame, themePickerFrame;
    CGRectDivide(bottomThird, &themeLabelFrame, &themePickerFrame, CGRectGetWidth(self.themeLabel.bounds), CGRectMinXEdge);
    self.themeLabel.frame = themeLabelFrame;
    themePickerFrame.origin.x += 16;
    themePickerFrame.size.width -= 16;
    self.themePicker.frame = themePickerFrame;
}

@end
