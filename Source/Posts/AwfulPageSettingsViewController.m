//  AwfulPageSettingsViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPageSettingsViewController.h"
#import "AwfulPageSettingsView.h"
#import "AwfulSettings.h"

@interface AwfulPageSettingsViewController ()

@end

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
    // TODO
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    _settingsView.avatarsEnabledSwitch.on = [AwfulSettings settings].showAvatars;
    _settingsView.imagesEnabledSwitch.on = [AwfulSettings settings].showImages;
    // TODO select current theme
}

- (CGSize)preferredContentSize
{
    return [self.view sizeThatFits:CGSizeMake(300, 1100)];
}

@end
