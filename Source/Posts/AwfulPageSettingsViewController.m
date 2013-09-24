//  AwfulPageSettingsViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPageSettingsViewController.h"
#import "AwfulPageSettingsView.h"
#import "AwfulSettings.h"

@implementation AwfulPageSettingsViewController
{
    AwfulPageSettingsView *_settingsView;
}

- (void)loadView
{
    _settingsView = [AwfulPageSettingsView new];
    [_settingsView.avatarsEnabledSwitch addTarget:self
                                           action:@selector(didTapAvatarsEnabledSwitch:)
                                 forControlEvents:UIControlEventValueChanged];
    [_settingsView.imagesEnabledSwitch addTarget:self
                                          action:@selector(didTapImagesEnabledSwitch:)
                                forControlEvents:UIControlEventValueChanged];
    [_settingsView.themePicker addTarget:self
                                  action:@selector(didTapThemePicker:)
                        forControlEvents:UIControlEventValueChanged];
    [self.themes enumerateObjectsUsingBlock:^(AwfulTheme *theme, NSUInteger i, BOOL *stop) {
        [_settingsView.themePicker insertThemeWithColor:theme.descriptiveColor atIndex:i];
    }];
    _settingsView.themePicker.selectedThemeIndex = [self.themes indexOfObject:self.selectedTheme];
    self.view = _settingsView;
}

- (void)didTapAvatarsEnabledSwitch:(UISwitch *)avatarsEnabledSwitch
{
    [AwfulSettings settings].showAvatars = avatarsEnabledSwitch.on;
}

- (void)didTapImagesEnabledSwitch:(UISwitch *)imagesEnabledSwitch
{
    [AwfulSettings settings].showImages = imagesEnabledSwitch.on;
}

- (void)didTapThemePicker:(AwfulThemePicker *)themePicker
{
    self.selectedTheme = self.themes[themePicker.selectedThemeIndex];
    [self.delegate pageSettingsSelectedThemeDidChange:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    _settingsView.avatarsEnabledSwitch.on = [AwfulSettings settings].showAvatars;
    _settingsView.imagesEnabledSwitch.on = [AwfulSettings settings].showImages;
}

- (CGSize)preferredContentSize
{
    return [self.view sizeThatFits:CGSizeMake(300, 1100)];
}

@end
