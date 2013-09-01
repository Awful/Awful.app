//  AwfulPostsSettingsView.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>
#import "AwfulThemePicker.h"

@interface AwfulPostsSettingsView : UIView

@property (readonly, weak, nonatomic) UILabel *showAvatarsLabel;
@property (readonly, weak, nonatomic) UISwitch *showAvatarsSwitch;
@property (readonly, weak, nonatomic) UILabel *showImagesLabel;
@property (readonly, weak, nonatomic) UISwitch *showImagesSwitch;
@property (readonly, weak, nonatomic) UILabel *fontSizeLabel;
@property (readonly, weak, nonatomic) UIStepper *fontSizeStepper;
@property (readonly, weak, nonatomic) UILabel *themeLabel;
@property (readonly, weak, nonatomic) AwfulThemePicker *themePicker;

@end
