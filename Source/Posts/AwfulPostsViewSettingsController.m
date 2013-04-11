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

@interface AwfulPostsViewSettingsController () <UITableViewDataSource, UITableViewDelegate>

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
    AwfulPostsSettingsView *view = [[AwfulPostsSettingsView alloc] initWithFrame:CGRectMake(0, 0, 320, 180)];
    view.showAvatarsLabel.text = @"Avatars";
    [view.showAvatarsSwitch addTarget:self action:@selector(didTapShowAvatarsSwitch:)
                     forControlEvents:UIControlEventValueChanged];
    view.showImagesLabel.text = @"Images";
    [view.showImagesSwitch addTarget:self action:@selector(didTapShowImagesSwitch:)
                    forControlEvents:UIControlEventValueChanged];
    [view.fontSizeControl addTarget:self action:@selector(didTapFontSizeSegment:)
                   forControlEvents:UIControlEventValueChanged];
    view.themeTableView.dataSource = self;
    view.themeTableView.delegate = self;
    view.themeTableView.rowHeight = 32;
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

- (void)didTapFontSizeSegment:(UISegmentedControl *)seg
{
    NSDictionary *info = [[AwfulSettings settings] infoForSettingWithKey:@"font_size"];
    NSInteger fontSize = [[AwfulSettings settings].fontSize integerValue];
    if (seg.selectedSegmentIndex == 0) {
        NSNumber *minimum = info[@"Minimum"];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && info[@"Minimum~ipad"]) {
            minimum = info[@"Minimum~ipad"];
        }
        if (fontSize > [minimum integerValue]) {
            fontSize -= 1;
        }
    } else if (seg.selectedSegmentIndex == 1) {
        NSNumber *maximum = info[@"Maximum"];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && info[@"Maximum~ipad"]) {
            maximum = info[@"Maximum~ipad"];
        }
        if (fontSize < [maximum integerValue]) {
            fontSize += 1;
        }
    }
    [AwfulSettings settings].fontSize = @(fontSize);
    seg.selectedSegmentIndex = UISegmentedControlNoSegment;
}

- (void)didTapDarkModeSegment:(UISegmentedControl *)seg
{
    if (seg.selectedSegmentIndex == 0) {
        [AwfulSettings settings].darkTheme = NO;
    } else if (seg.selectedSegmentIndex == 1) {
        [AwfulSettings settings].darkTheme = YES;
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.settingsView.showAvatarsSwitch.on = [AwfulSettings settings].showAvatars;
    self.settingsView.showImagesSwitch.on = [AwfulSettings settings].showImages;
    NSIndexPath *markedIndexPath = [NSIndexPath indexPathForRow:[self selectedThemeIndex]
                                                      inSection:0];
    [self.settingsView.themeTableView scrollToRowAtIndexPath:markedIndexPath
                                            atScrollPosition:UITableViewScrollPositionBottom
                                                    animated:NO];
}

#pragma mark - UITableViewDataSource and UITableViewDelegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (self.availableThemes) {
        case AwfulPostsViewSettingsControllerThemesDefault: return 2;
        case AwfulPostsViewSettingsControllerThemesGasChamber: return 3;
        case AwfulPostsViewSettingsControllerThemesFYAD: return 3;
        case AwfulPostsViewSettingsControllerThemesYOSPOS: return 6;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * const Identifier = @"CellIdentifier";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:Identifier];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
                                      reuseIdentifier:Identifier];
        cell.textLabel.font = [UIFont systemFontOfSize:18];
    }
    if (indexPath.row == 0) {
        cell.textLabel.text = @"Light";
    } else if (indexPath.row == 1) {
        cell.textLabel.text = @"Dark";
    } else if (self.availableThemes == AwfulPostsViewSettingsControllerThemesGasChamber) {
        if (indexPath.row == 2) {
            cell.textLabel.text = @"Sickly";
        }
    } else if (self.availableThemes == AwfulPostsViewSettingsControllerThemesFYAD) {
        if (indexPath.row == 2) {
            cell.textLabel.text = @"Pink";
        }
    } else if (self.availableThemes == AwfulPostsViewSettingsControllerThemesYOSPOS) {
        switch (indexPath.row) {
            case 2: cell.textLabel.text = @"Green"; break;
            case 3: cell.textLabel.text = @"Amber"; break;
            case 4: cell.textLabel.text = @"Macinyos"; break;
            case 5: cell.textLabel.text = @"Winpos 95"; break;
        }
    }
    if (indexPath.row == [self selectedThemeIndex]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    return cell;
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

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == [self selectedThemeIndex]) return nil;
    return indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == [self selectedThemeIndex]) return;
    NSIndexPath *markedIndexPath = [NSIndexPath indexPathForRow:[self selectedThemeIndex]
                                                      inSection:0];
    UITableViewCell *hadCheckmark = [tableView cellForRowAtIndexPath:markedIndexPath];
    hadCheckmark.accessoryType = UITableViewCellAccessoryNone;
    if (indexPath.row < 2) {
        [AwfulSettings settings].darkTheme = indexPath.row == 1;
    }
    switch (self.availableThemes) {
        case AwfulPostsViewSettingsControllerThemesDefault: break;
        case AwfulPostsViewSettingsControllerThemesGasChamber:
            switch (indexPath.row) {
                case 0: case 1:
                    [AwfulSettings settings].gasChamberStyle = AwfulGasChamberStyleNone; break;
                case 2:
                    [AwfulSettings settings].gasChamberStyle = AwfulGasChamberStyleSickly; break;
            }
        case AwfulPostsViewSettingsControllerThemesFYAD:
            switch (indexPath.row) {
                case 0: case 1:
                    [AwfulSettings settings].fyadStyle = AwfulFYADStyleNone; break;
                case 2:
                    [AwfulSettings settings].fyadStyle = AwfulFYADStylePink; break;
            }
        case AwfulPostsViewSettingsControllerThemesYOSPOS:
            switch (indexPath.row) {
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
    UITableViewCell *nowHasCheckmark = [tableView cellForRowAtIndexPath:indexPath];
    nowHasCheckmark.accessoryType = UITableViewCellAccessoryCheckmark;
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
