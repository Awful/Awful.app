//  AwfulInstapaperLogInController.h
//
//  Copyright 2013 Awful Contributors. CC BY-NC-SA 3.0 US https://github.com/Awful/Awful.app

#import <UIKit/UIKit.h>
@protocol AwfulInstapaperLogInControllerDelegate;

@interface AwfulInstapaperLogInController : UITableViewController

@property (copy, nonatomic) NSString *username;
@property (copy, nonatomic) NSString *password;

@property (weak, nonatomic) id <AwfulInstapaperLogInControllerDelegate> delegate;

@end


@protocol AwfulInstapaperLogInControllerDelegate <NSObject>

- (void)instapaperLogInControllerDidSucceed:(AwfulInstapaperLogInController *)logIn;
- (void)instapaperLogInControllerDidCancel:(AwfulInstapaperLogInController *)logIn;

@end
