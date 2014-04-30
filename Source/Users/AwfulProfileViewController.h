//  AwfulProfileViewController.h
//
//  Copyright 2012 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
#import "AwfulModels.h"

/**
 * An AwfulProfileViewController shows a user's profile. If it's presented, it'll add a "Done" button as its left navigation item.
 */
@interface AwfulProfileViewController : AwfulViewController

/**
 * Designated initializer.
 */
- (id)initWithUser:(AwfulUser *)user;

@property (readonly, strong, nonatomic) AwfulUser *user;

@end
