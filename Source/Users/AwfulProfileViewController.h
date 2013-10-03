//  AwfulProfileViewController.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
#import "AwfulModels.h"

@interface AwfulProfileViewController : AwfulViewController

// Designated initializer.
- (id)initWithUser:(AwfulUser *)user;

@property (readonly, strong, nonatomic) AwfulUser *user;

@end
