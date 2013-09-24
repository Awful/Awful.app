//  AwfulPageSettingsViewController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
@protocol AwfulPageSettingsViewControllerDelegate;

/**
 * An AwfulPageSettingsViewController allows changing relevant settings on a page of posts.
 */
@interface AwfulPageSettingsViewController : AwfulViewController

/**
 * An array of AwfulTheme objects that can be selected.
 */
@property (copy, nonatomic) NSArray *themes;

/**
 * The currently-selected theme. Must be contained in the themes array.
 */
@property (strong, nonatomic) AwfulTheme *selectedTheme;

/**
 * The delegate.
 */
@property (weak, nonatomic) id <AwfulPageSettingsViewControllerDelegate> delegate;

@end

@protocol AwfulPageSettingsViewControllerDelegate <NSObject>

/**
 * Informs the delegate that the currently-selected theme has changed. Consult the selectedTheme property on the page settings controller.
 */
- (void)pageSettingsSelectedThemeDidChange:(AwfulPageSettingsViewController *)pageSettings;

@end
