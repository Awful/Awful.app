//
//  AwfulPostsViewSettingsController.h
//  Awful
//
//  Created by Nolan Waite on 2013-03-27.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

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
