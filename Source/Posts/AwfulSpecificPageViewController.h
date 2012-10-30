//
//  AwfulSpecificPageViewController.h
//  Awful
//
//  Created by Sean Berry on 10/18/11.
//  Copyright (c) 2011 Regular Berry Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>
@class AwfulPage;

@interface AwfulSpecificPageViewController : UIViewController

@property (nonatomic, weak) AwfulPage *page;

@property (nonatomic) UIPickerView *pickerView;

@property (nonatomic) BOOL hiding;

@end
