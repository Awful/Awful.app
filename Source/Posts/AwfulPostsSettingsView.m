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
@property (weak, nonatomic) UISegmentedControl *fontSizeControl;
@property (weak, nonatomic) UITableView *themeTableView;

@end


@implementation AwfulPostsSettingsView

#pragma mark - UIView

- (id)initWithFrame:(CGRect)frame
{
    if (!(self = [super initWithFrame:frame])) return nil;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    self.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.8];
    
    #define AddAndSetSubview(viewClass, ivar) do { \
        viewClass *ivar = [viewClass new]; \
        [self addSubview:ivar]; \
        _##ivar = ivar; \
    } while (0)
    AddAndSetSubview(UILabel, showAvatarsLabel);
    self.showAvatarsLabel.backgroundColor = [UIColor clearColor];
    self.showAvatarsLabel.textColor = [UIColor whiteColor];
    AddAndSetSubview(UISwitch, showAvatarsSwitch);
    AddAndSetSubview(UILabel, showImagesLabel);
    self.showImagesLabel.backgroundColor = [UIColor clearColor];
    self.showImagesLabel.textColor = [UIColor whiteColor];
    AddAndSetSubview(UISwitch, showImagesSwitch);
    AddAndSetSubview(UITableView, themeTableView);
    
    UIImage *smallerFontSize = [UIImage imageNamed:@"font-size-smaller.png"];
    smallerFontSize.accessibilityLabel = @"Shrink font size";
    UIImage *largerFontSize = [UIImage imageNamed:@"font-size-larger.png"];
    largerFontSize.accessibilityLabel = @"Embiggen font size";
    NSArray *fontSizeItems = @[ smallerFontSize, largerFontSize ];
    UISegmentedControl *fontSizeControl = [[UISegmentedControl alloc] initWithItems:fontSizeItems];
    [self addSubview:fontSizeControl];
    _fontSizeControl = fontSizeControl;
    return self;
}

- (void)layoutSubviews
{
    CGRect leftHalf, rightHalf;
    CGRectDivide(self.bounds, &leftHalf, &rightHalf, floorf(CGRectGetWidth(self.bounds) / 2), CGRectMinXEdge);
    leftHalf = CGRectInset(leftHalf, 5, 10);
    rightHalf = CGRectInset(rightHalf, 5, 10);
    
    CGRect avatarsSixth, remainder, imagesSixth, fontSizeSixth;
    CGRectDivide(leftHalf, &avatarsSixth, &remainder, floorf(CGRectGetHeight(leftHalf) / 3), CGRectMinYEdge);
    CGRectDivide(remainder, &imagesSixth, &fontSizeSixth, CGRectGetHeight(avatarsSixth), CGRectMinYEdge);
    
    CGFloat switchHeight = CGRectGetHeight(self.showAvatarsSwitch.bounds);
    CGRect avatarsLabelFrame, avatarsSwitchFrame;
    CGRectDivide(avatarsSixth, &avatarsSwitchFrame, &avatarsLabelFrame, CGRectGetWidth(self.showAvatarsSwitch.bounds), CGRectMaxXEdge);
    self.showAvatarsLabel.frame = avatarsLabelFrame;
    avatarsSwitchFrame.origin.y = CGRectGetMidY(avatarsSwitchFrame) - switchHeight / 2;
    avatarsSwitchFrame.size.height = switchHeight;
    self.showAvatarsSwitch.frame = avatarsSwitchFrame;
    
    CGRect imagesLabelFrame, imagesSwitchFrame;
    CGRectDivide(imagesSixth, &imagesSwitchFrame, &imagesLabelFrame, CGRectGetWidth(self.showImagesSwitch.bounds), CGRectMaxXEdge);
    self.showImagesLabel.frame = imagesLabelFrame;
    imagesSwitchFrame.origin.y = CGRectGetMidY(imagesSwitchFrame) - switchHeight / 2;
    imagesSwitchFrame.size.height = switchHeight;
    self.showImagesSwitch.frame = imagesSwitchFrame;
    
    self.fontSizeControl.frame = CGRectMake(0, 0, 90, 34);
    self.fontSizeControl.center = CGPointMake(CGRectGetMidX(fontSizeSixth), CGRectGetMidY(fontSizeSixth));
    
    self.themeTableView.frame = CGRectInset(rightHalf, 5, 5);
}

@end
