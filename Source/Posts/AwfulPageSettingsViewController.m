//  AwfulPageSettingsViewController.m
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulPageSettingsViewController.h"
#import "AwfulPageSettingsView.h"
#import "AwfulSettings.h"
#import "AwfulThemeLoader.h"

@interface AwfulPageSettingsViewController ()

@property (readonly, strong, nonatomic) AwfulPageSettingsView *settingsView;

@property (readonly, copy, nonatomic) NSArray *themes;

@end

@implementation AwfulPageSettingsViewController
{
    NSArray *_themes;
}

- (id)initWithForum:(AwfulForum *)forum
{
    self = [super init];
    if (!self) return nil;
    _forum = forum;
    self.title = @"Formatting Options";
    return self;
}

- (AwfulPageSettingsView *)settingsView
{
    return (AwfulPageSettingsView *)self.view;
}

- (NSArray *)themes
{
    if (_themes) return _themes;
    _themes = [[AwfulThemeLoader sharedLoader] themesForForumWithID:self.forum.forumID];
    return _themes;
}

- (void)setSelectedTheme:(AwfulTheme *)selectedTheme
{
    _selectedTheme = selectedTheme;
    if ([self isViewLoaded]) {
        self.settingsView.themePicker.selectedThemeIndex = [self.themes indexOfObject:selectedTheme];
    }
}

- (void)setTitle:(NSString *)title
{
    [super setTitle:title];
    if ([self isViewLoaded]) {
        self.settingsView.titleLabel.text = self.title;
    }
}

- (void)loadView
{
    AwfulPageSettingsView *settingsView = [AwfulPageSettingsView new];
    settingsView.titleLabel.text = self.title;
    [settingsView.avatarsEnabledSwitch addTarget:self
                                          action:@selector(didTapAvatarsEnabledSwitch:)
                                forControlEvents:UIControlEventValueChanged];
    [settingsView.imagesEnabledSwitch addTarget:self
                                         action:@selector(didTapImagesEnabledSwitch:)
                               forControlEvents:UIControlEventValueChanged];
    [settingsView.themePicker addTarget:self
                                 action:@selector(didTapThemePicker:)
                       forControlEvents:UIControlEventValueChanged];
    [settingsView.fontScaleStepper addTarget:self
                                      action:@selector(didTapFontScaleStepper:)
                            forControlEvents:UIControlEventValueChanged];
    [self.themes enumerateObjectsUsingBlock:^(AwfulTheme *theme, NSUInteger i, BOOL *stop) {
        UIColor *color = theme.descriptiveColor;
        color.accessibilityLabel = theme.descriptiveName;
        [settingsView.themePicker insertThemeWithColor:color atIndex:i];
    }];
    settingsView.themePicker.selectedThemeIndex = [self.themes indexOfObject:self.selectedTheme];
    self.view = settingsView;
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
    AwfulTheme *theme = self.themes[themePicker.selectedThemeIndex];
    self.selectedTheme = theme;
    [[AwfulSettings settings] setThemeName:theme.name forForumID:self.forum.forumID];
    if (!theme.forumSpecific) {
        [AwfulSettings settings].darkTheme = ![theme isEqual:[AwfulThemeLoader sharedLoader].defaultTheme];
    }
}

- (void)didTapFontScaleStepper:(UIStepper *)fontScaleStepper
{
    [AwfulSettings settings].fontScale = fontScaleStepper.value;
    [[self settingsView] updateFontScaleLabel];
}

- (void)themeDidChange
{
    [super themeDidChange];
    AwfulTheme *theme = self.theme;
    AwfulPageSettingsView *settingsView = self.settingsView;
    settingsView.tintColor = theme[@"tintColor"];
    settingsView.backgroundColor = theme[@"sheetBackgroundColor"];
    settingsView.titleLabel.textColor = theme[@"sheetTitleColor"];
    settingsView.titleBackgroundColor = theme[@"sheetTitleBackgroundColor"];
    settingsView.avatarsLabel.textColor = theme[@"sheetTextColor"];
    settingsView.imagesLabel.textColor = theme[@"sheetTextColor"];
    settingsView.themeLabel.textColor = theme[@"sheetTextColor"];
    settingsView.avatarsEnabledSwitch.onTintColor = theme[@"settingsSwitchColor"];
    settingsView.imagesEnabledSwitch.onTintColor = theme[@"settingsSwitchColor"];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.settingsView.avatarsEnabledSwitch.on = [AwfulSettings settings].showAvatars;
    self.settingsView.imagesEnabledSwitch.on = [AwfulSettings settings].showImages;
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    UILabel *titleLabel = self.settingsView.titleLabel;
    titleLabel.preferredMaxLayoutWidth = CGRectGetWidth(titleLabel.bounds);
    AwfulThemePicker *themePicker = self.settingsView.themePicker;
    themePicker.preferredMaxLayoutWidth = CGRectGetWidth(themePicker.bounds);
    [self.settingsView layoutIfNeeded];
}

- (CGSize)preferredContentSize
{
    CGRect bounds = self.view.bounds;
    if (CGRectGetWidth(bounds) < 320) {
        bounds.size.width = 320;
    }
    self.view.bounds = bounds;
    [self.view layoutIfNeeded];
    CGSize contentSize = self.settingsView.intrinsicContentSize;
    return CGSizeMake(320, contentSize.height);
}

@end
