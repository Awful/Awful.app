//  AwfulPostsViewSettingsController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulSemiModalViewController.h"
@protocol AwfulPostsViewSettingsControllerDelegate;

typedef NS_ENUM(NSInteger, AwfulPostsViewSettingsControllerThemes) {
    AwfulPostsViewSettingsControllerThemesDefault,
    AwfulPostsViewSettingsControllerThemesGasChamber,
    AwfulPostsViewSettingsControllerThemesFYAD,
    AwfulPostsViewSettingsControllerThemesYOSPOS,
};


@interface AwfulPostsViewSettingsController : AwfulSemiModalViewController

@property (weak, nonatomic) id <AwfulPostsViewSettingsControllerDelegate> delegate;
@property (nonatomic) AwfulPostsViewSettingsControllerThemes availableThemes;

@end


@protocol AwfulPostsViewSettingsControllerDelegate <NSObject>

- (void)userDidDismissPostsViewSettings:(AwfulPostsViewSettingsController *)settings;

@end
