//
//  AwfulLoginController.h
//  Awful
//
//  Copyright 2010 Awful Contributors. CC BY-NC-SA 3.0 US http://github.com/AwfulDevs/Awful
//

#import <UIKit/UIKit.h>

@protocol AwfulLoginControllerDelegate;


@interface AwfulLoginController : UITableViewController

@property (weak, nonatomic) id <AwfulLoginControllerDelegate> delegate;

@end


@protocol AwfulLoginControllerDelegate <NSObject>

// userInfo has keys "userID" and "username".
- (void)loginController:(AwfulLoginController *)login
 didLogInAsUserWithInfo:(NSDictionary *)userInfo;

- (void)loginController:(AwfulLoginController *)login didFailToLogInWithError:(NSError *)error;

@end
