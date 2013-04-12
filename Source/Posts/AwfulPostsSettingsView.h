//
//  AwfulPostsSettingsView.h
//  Awful
//
//  Created by Nolan Waite on 2013-04-11.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

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
