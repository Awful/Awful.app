//
//  AwfulSpecificPageViewController.h
//  Awful
//
//  Created by Sean Berry on 10/18/11.
//  Copyright (c) 2011 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
@class AwfulPostsViewController;

@interface AwfulSpecificPageViewController : UIViewController

@property (nonatomic, weak) AwfulPostsViewController *page;

@property (nonatomic) UIPickerView *pickerView;

@property (nonatomic) BOOL hiding;

@end
