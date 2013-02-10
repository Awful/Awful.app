//
//  AwfulLoginController.h
//  Awful
//
//  Created by Sean Berry on 7/26/10.
//  Copyright 2010 Regular Berry Software LLC. All rights reserved.
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
