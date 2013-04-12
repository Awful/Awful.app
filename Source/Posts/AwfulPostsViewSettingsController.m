//
//  AwfulPostsViewSettingsController.m
//  Awful
//
//  Created by Nolan Waite on 2013-03-27.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulPostsViewSettingsController.h"
#import "AwfulPostsSettingsView.h"
#import "AwfulSettings.h"

@interface AwfulPostsViewSettingsController ()

@property (readonly, nonatomic) AwfulPostsSettingsView *settingsView;

@end


@implementation AwfulPostsViewSettingsController

- (AwfulPostsSettingsView *)settingsView
{
    return (id)self.view;
}

#pragma mark - AwfulSemiModalViewController

- (void)presentFromViewController:(UIViewController *)viewController fromView:(UIView *)view
{
    self.coverView.backgroundColor = nil;
    [super presentFromViewController:viewController fromView:view];
}

- (void)userDismiss
{
    [self.delegate userDidDismissPostsViewSettings:self];
    [self dismiss];
}

#pragma mark - UIViewController

- (void)loadView
{
    AwfulPostsSettingsView *view = [[AwfulPostsSettingsView alloc] initWithFrame:CGRectMake(0, 0, 320, 152)];
    [view.showAvatarsSwitch addTarget:self action:@selector(didTapShowAvatarsSwitch:)
                     forControlEvents:UIControlEventValueChanged];
    [view.showImagesSwitch addTarget:self action:@selector(didTapShowImagesSwitch:)
                    forControlEvents:UIControlEventValueChanged];
    [view.fontSizeStepper addTarget:self action:@selector(didTapFontSizeStepper:)
                   forControlEvents:UIControlEventValueChanged];
    [view.themePicker addTarget:self action:@selector(didSelectThemeFromPicker:)
               forControlEvents:UIControlEventValueChanged];
    UIColor *light = [UIColor whiteColor];
    light.accessibilityLabel = @"Light";
    [view.themePicker insertThemeWithColor:light atIndex:0];
    UIColor *dark = [UIColor blackColor];
    dark.accessibilityLabel = @"Dark";
    [view.themePicker insertThemeWithColor:dark atIndex:1];
    if (self.availableThemes == AwfulPostsViewSettingsControllerThemesGasChamber) {
        UIColor *sickly = [UIColor colorWithHue:0.268 saturation:0.819 brightness:0.8 alpha:1];
        sickly.accessibilityLabel = @"Sickly";
        [view.themePicker insertThemeWithColor:sickly atIndex:2];
    } else if (self.availableThemes == AwfulPostsViewSettingsControllerThemesFYAD) {
        UIColor *pink = [UIColor colorWithHue:1 saturation:0.395 brightness:0.992 alpha:1];
        pink.accessibilityLabel = @"Pink";
        [view.themePicker insertThemeWithColor:pink atIndex:2];
    } else if (self.availableThemes == AwfulPostsViewSettingsControllerThemesYOSPOS) {
        UIColor *green = [UIColor colorWithHue:0.333 saturation:0.656 brightness:0.992 alpha:1];
        green.accessibilityLabel = @"Green console";
        [view.themePicker insertThemeWithColor:green atIndex:2];
        UIColor *amber = [UIColor colorWithHue:0.138 saturation:0.675 brightness:0.918 alpha:1];
        amber.accessibilityLabel = @"Amber console";
        [view.themePicker insertThemeWithColor:amber atIndex:3];
        UIColor *finder = [UIColor colorWithWhite:0.945 alpha:1];
        finder.accessibilityLabel = @"Macinyos";
        [view.themePicker insertThemeWithColor:finder atIndex:4];
        UIColor *windows = [UIColor colorWithHue:0.5 saturation:0.867 brightness:0.502 alpha:1];
        windows.accessibilityLabel = @"Winpos 95";
        [view.themePicker insertThemeWithColor:windows atIndex:5];
    }
    self.view = view;
}

- (void)didTapShowAvatarsSwitch:(UISwitch *)showAvatarsSwitch
{
    [AwfulSettings settings].showAvatars = showAvatarsSwitch.on;
}

- (void)didTapShowImagesSwitch:(UISwitch *)showImagesSwitch
{
    [AwfulSettings settings].showImages = showImagesSwitch.on;
}

- (void)didTapFontSizeStepper:(UIStepper *)stepper
{
    [AwfulSettings settings].fontSize = @(stepper.value);
}

- (void)didSelectThemeFromPicker:(AwfulThemePicker *)picker
{
    if (picker.selectedThemeIndex < 2) {
        [AwfulSettings settings].darkTheme = picker.selectedThemeIndex == 1;
    }
    switch (self.availableThemes) {
        case AwfulPostsViewSettingsControllerThemesDefault: break;
        case AwfulPostsViewSettingsControllerThemesGasChamber:
            switch (picker.selectedThemeIndex) {
                case 0: case 1:
                    [AwfulSettings settings].gasChamberStyle = AwfulGasChamberStyleNone; break;
                case 2:
                    [AwfulSettings settings].gasChamberStyle = AwfulGasChamberStyleSickly; break;
            }
        case AwfulPostsViewSettingsControllerThemesFYAD:
            switch (picker.selectedThemeIndex) {
                case 0: case 1:
                    [AwfulSettings settings].fyadStyle = AwfulFYADStyleNone; break;
                case 2:
                    [AwfulSettings settings].fyadStyle = AwfulFYADStylePink; break;
            }
        case AwfulPostsViewSettingsControllerThemesYOSPOS:
            switch (picker.selectedThemeIndex) {
                case 0: case 1:
                    [AwfulSettings settings].yosposStyle = AwfulYOSPOSStyleNone; break;
                case 2:
                    [AwfulSettings settings].yosposStyle = AwfulYOSPOSStyleGreen; break;
                case 3:
                    [AwfulSettings settings].yosposStyle = AwfulYOSPOSStyleAmber; break;
                case 4:
                    [AwfulSettings settings].yosposStyle = AwfulYOSPOSStyleMacinyos; break;
                case 5:
                    [AwfulSettings settings].yosposStyle = AwfulYOSPOSStyleWinpos95; break;
            }
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.settingsView.showAvatarsSwitch.on = [AwfulSettings settings].showAvatars;
    self.settingsView.showImagesSwitch.on = [AwfulSettings settings].showImages;
    [self configureFontSizeStepper];
    self.settingsView.fontSizeStepper.value = [[AwfulSettings settings].fontSize doubleValue];
    self.settingsView.themePicker.selectedThemeIndex = [self selectedThemeIndex];
}

- (void)configureFontSizeStepper
{
    NSDictionary *info = [[AwfulSettings settings] infoForSettingWithKey:@"font_size"];
    NSNumber *minimum = info[@"Minimum"];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && info[@"Minimum~ipad"]) {
        minimum = info[@"Minimum~ipad"];
    }
    self.settingsView.fontSizeStepper.minimumValue = [minimum doubleValue];
    NSNumber *maximum = info[@"Maximum"];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && info[@"Maximum~ipad"]) {
        maximum = info[@"Maximum~ipad"];
    }
    self.settingsView.fontSizeStepper.maximumValue = [maximum doubleValue];
    self.settingsView.fontSizeStepper.stepValue = [info[@"Increment"] doubleValue];
}

- (NSInteger)selectedThemeIndex
{
    NSInteger defaultIndex = [AwfulSettings settings].darkTheme ? 1 : 0;
    switch (self.availableThemes) {
        case AwfulPostsViewSettingsControllerThemesDefault: return defaultIndex;
        case AwfulPostsViewSettingsControllerThemesGasChamber:
            switch ([AwfulSettings settings].gasChamberStyle) {
                case AwfulGasChamberStyleNone: return defaultIndex;
                case AwfulGasChamberStyleSickly: return 2;
            }
        case AwfulPostsViewSettingsControllerThemesFYAD:
            switch ([AwfulSettings settings].fyadStyle) {
                case AwfulFYADStyleNone: return defaultIndex;
                case AwfulFYADStylePink: return 2;
            }
        case AwfulPostsViewSettingsControllerThemesYOSPOS:
            switch ([AwfulSettings settings].yosposStyle) {
                case AwfulYOSPOSStyleNone: return defaultIndex;
                case AwfulYOSPOSStyleGreen: return 2;
                case AwfulYOSPOSStyleAmber: return 3;
                case AwfulYOSPOSStyleMacinyos: return 4;
                case AwfulYOSPOSStyleWinpos95: return 5;
            }
    }
}

@end
