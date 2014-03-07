//  AwfulPageSettingsViewController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "AwfulSemiModalViewController.h"

/**
 * An AwfulPageSettingsViewController allows changing relevant settings on a page of posts.
 */
@interface AwfulPageSettingsViewController : AwfulSemiModalViewController

- (id)initWithForum:(AwfulForum *)forum;

@property (readonly, strong, nonatomic) AwfulForum *forum;

@property (strong, nonatomic) AwfulTheme *selectedTheme;

@end
