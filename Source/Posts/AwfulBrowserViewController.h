//
//  AwfulBrowserViewController.h
//  Awful
//
//  Created by Nolan Waite on 2012-12-19.
//  Copyright (c) 2012 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
@protocol AwfulBrowserViewControllerDelegate;

@interface AwfulBrowserViewController : UIViewController

@property (weak, nonatomic) id <AwfulBrowserViewControllerDelegate> delegate;

@property (nonatomic) NSURL *URL;

@end


@protocol AwfulBrowserViewControllerDelegate <NSObject>

- (void)browserDidClose:(AwfulBrowserViewController *)browser;

@end
