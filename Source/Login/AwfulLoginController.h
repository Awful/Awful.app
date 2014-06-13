//  AwfulLoginController.h
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import "UIViewController+AwfulTheme.h"
@protocol AwfulLoginControllerDelegate;

/**
 * An AwfulLoginController displays a form for entering a username and password.
 */
@interface AwfulLoginController : AwfulTableViewController

@property (weak, nonatomic) id <AwfulLoginControllerDelegate> delegate;

@end

@protocol AwfulLoginControllerDelegate <NSObject>

- (void)loginController:(AwfulLoginController *)login didLogInAsUser:(AwfulUser *)user;

/**
 * @param error An NSError object in the AFNetworkingErrorDomain.
 */
- (void)loginController:(AwfulLoginController *)login didFailToLogInWithError:(NSError *)error;

@end

/**
 * Sent when a user logs in. The notification's object is an AwfulUser instance representing the logged-in user.
 */
extern NSString * const AwfulUserDidLogInNotification;
