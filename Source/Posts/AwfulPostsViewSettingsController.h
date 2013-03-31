//
//  AwfulPostsViewSettingsController.h
//  Awful
//
//  Created by Nolan Waite on 2013-03-27.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

#import "AwfulSemiModalViewController.h"
@protocol AwfulPostsViewSettingsControllerDelegate;

@interface AwfulPostsViewSettingsController : AwfulSemiModalViewController

@property (weak, nonatomic) id <AwfulPostsViewSettingsControllerDelegate> delegate;

@end


@protocol AwfulPostsViewSettingsControllerDelegate <NSObject>

- (void)userDidDismissPostsViewSettings:(AwfulPostsViewSettingsController *)settings;

@end
