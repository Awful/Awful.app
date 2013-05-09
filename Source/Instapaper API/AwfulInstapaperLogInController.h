//
//  AwfulInstapaperLogInController.h
//  Awful
//
//  Created by Nolan Waite on 2013-05-09.
//  Copyright (c) 2013 Awful Contributors. All rights reserved.
//

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
