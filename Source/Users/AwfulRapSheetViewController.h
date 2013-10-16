//  AwfulRapSheetViewController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
#import "AwfulModels.h"

/**
 * An AwfulRapSheetViewController displays a list of probations and bans.
 */
@interface AwfulRapSheetViewController : AwfulTableViewController

/**
 * Returns an initialized AwfulRapSheetViewController. This is the designated initializer.
 *
 * @param user The user whose bans and probations are shown, or nil to show all users.
 */
- (id)initWithUser:(AwfulUser *)user;

/**
 * The user whose bans and probations are shown. Can be nil, in which case all users' bans and probations are shown.
 */
@property (readonly, strong, nonatomic) AwfulUser *user;

@end
