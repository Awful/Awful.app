//
//  AwfulPostsSettingsView.h
//  Awful
//
//  Created by Nolan Waite on 2013-04-11.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AwfulPostsSettingsView : UIView

@property (readonly, weak, nonatomic) UILabel *showAvatarsLabel;
@property (readonly, weak, nonatomic) UISwitch *showAvatarsSwitch;
@property (readonly, weak, nonatomic) UILabel *showImagesLabel;
@property (readonly, weak, nonatomic) UISwitch *showImagesSwitch;
@property (readonly, weak, nonatomic) UISegmentedControl *fontSizeControl;
@property (readonly, weak, nonatomic) UITableView *themeTableView;

@end
