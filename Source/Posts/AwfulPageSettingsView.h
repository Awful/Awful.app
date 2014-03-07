//  AwfulPageSettingsView.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>
#import "AwfulThemePicker.h"

/**
 * An AwfulPageSettingsView lays out the switches and buttons for in-page settings.
 */
@interface AwfulPageSettingsView : UIView

/**
 * Describes the avatarsEnabledSwitch. Default text is "Avatars".
 */
@property (readonly, strong, nonatomic) UILabel *avatarsLabel;

/**
 * Toggles whether avatars are visible ("on") or invisible ("off").
 */
@property (readonly, strong, nonatomic) UISwitch *avatarsEnabledSwitch;

/**
 * Describes the imagesEnabledSwitch. Default text is "Images".
 */
@property (readonly, strong, nonatomic) UILabel *imagesLabel;

/**
 * Toggles whether images are visible ("on") or turned into links ("off").
 */
@property (readonly, strong, nonatomic) UISwitch *imagesEnabledSwitch;

/**
 * Describes the themePicker. Default text is "Theme".
 */
@property (readonly, strong, nonatomic) UILabel *themeLabel;

/**
 * Chooses the currently-selected theme.
 */
@property (readonly, strong, nonatomic) AwfulThemePicker *themePicker;

@end
